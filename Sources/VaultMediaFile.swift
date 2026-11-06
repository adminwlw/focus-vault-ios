import CoreTransferable
import CryptoKit
import Foundation
import UniformTypeIdentifiers
import AVFoundation
import ImageIO
import UIKit

struct VaultFileInfo: Sendable {
    let size: Int
    let digest: String
    let thumbnail: Data?
    let capturedAt: Date?
    let duration: Double?
}

struct PickedVaultFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try copy(received.file)
        }
        FileRepresentation(importedContentType: .image) { received in
            try copy(received.file)
        }
    }

    private static func copy(_ source: URL) throws -> Self {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VaultImport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
            return Self(url: destination)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}

// Each chunk authenticates the file header and its position, including the total plaintext length.
// Legacy AES-GCM media remain readable. New videos never require a whole-file plaintext buffer.
enum VaultMediaFile {
    private static let magic = Data("FVCH001\n".utf8)
    private static let chunkSize = 1_048_576

    static func run<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        let worker = Task.detached(priority: .userInitiated, operation: operation)
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func inspect(_ url: URL, kind: VaultMediaKind) throws -> VaultFileInfo {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw ValidationError("文件为空。") }
        let hash = try digest(url)
        var thumbnail: Data?
        var capturedAt: Date?
        var duration: Double?
        if kind == .photo {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512
                  ] as CFDictionary) else { throw ValidationError("照片格式无法读取。") }
            thumbnail = UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
               let value = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                capturedAt = formatter.date(from: value)
            }
        } else {
            let asset = AVURLAsset(url: url)
            guard asset.isPlayable else { throw ValidationError("视频无法播放，原件已保留。") }
            let seconds = CMTimeGetSeconds(asset.duration)
            if seconds.isFinite, seconds > 0, seconds < Double(Int.max) { duration = seconds }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 512, height: 512)
            if let frame = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                thumbnail = UIImage(cgImage: frame).jpegData(compressionQuality: 0.82)
            }
        }
        return VaultFileInfo(size: size, digest: hash, thumbnail: thumbnail, capturedAt: capturedAt, duration: duration)
    }

    static func digest(_ url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hash = SHA256()
        while let bytes = try input.read(upToCount: chunkSize), !bytes.isEmpty {
            try Task.checkCancellation()
            hash.update(data: bytes)
        }
        return hex(hash.finalize())
    }

    static func encrypt(_ source: URL, to destination: URL, key: Data) throws -> String {
        let length = UInt64(try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard length > 0 else { throw ValidationError("文件为空。") }
        let header = magic + number(length) + (try CryptoBox.randomData(count: 16))
        let staging = destination.appendingPathExtension(UUID().uuidString + ".partial")
        defer { try? FileManager.default.removeItem(at: staging) }
        try Data().write(to: staging, options: .completeFileProtection)
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: staging)
        defer { try? input.close(); try? output.close() }
        try output.write(contentsOf: header)
        var hash = SHA256()
        var position: UInt64 = 0
        var written: UInt64 = 0
        while let bytes = try input.read(upToCount: chunkSize), !bytes.isEmpty {
            try Task.checkCancellation()
            let sealed = try AES.GCM.seal(bytes, using: SymmetricKey(data: key), authenticating: header + number(position))
            guard let combined = sealed.combined else { throw AppSecurityError.invalidCiphertext }
            try output.write(contentsOf: combined)
            hash.update(data: bytes)
            written += UInt64(bytes.count)
            position += 1
        }
        guard written == length else { throw ValidationError("导入期间文件发生变化。") }
        try output.synchronize()
        try output.close()
        // Validate every authentication tag and the complete length before making the file visible.
        let expected = hex(hash.finalize())
        guard try decryptedDigest(staging, key: key) == expected else { throw AppSecurityError.invalidCiphertext }
        try FileManager.default.moveItem(at: staging, to: destination)
        return expected
    }

    @discardableResult
    static func decrypt(_ source: URL, to destination: URL, key: Data) throws -> String {
        let staging = destination.appendingPathExtension(UUID().uuidString + ".partial")
        defer { try? FileManager.default.removeItem(at: staging) }
        try Data().write(to: staging, options: .completeFileProtection)
        let output = try FileHandle(forWritingTo: staging)
        do {
            let hash = try read(source, key: key) { try output.write(contentsOf: $0) }
            try output.close()
            try FileManager.default.moveItem(at: staging, to: destination)
            return hash
        } catch {
            try? output.close()
            throw error
        }
    }

    static func data(_ source: URL, key: Data) throws -> Data {
        var result = Data()
        _ = try read(source, key: key) { result.append($0) }
        return result
    }

    static func decryptedDigest(_ source: URL, key: Data) throws -> String {
        try read(source, key: key) { _ in }
    }

    private static func read(_ source: URL, key: Data, consume: (Data) throws -> Void) throws -> String {
        try Task.checkCancellation()
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let prefix = try input.read(upToCount: magic.count) ?? Data()
        guard prefix == magic else {
            let plaintext = try CryptoBox.open(Data(contentsOf: source), using: key)
            try consume(plaintext)
            return hex(SHA256.hash(data: plaintext))
        }
        let tail = try input.read(upToCount: 24) ?? Data()
        guard tail.count == 24 else { throw AppSecurityError.invalidCiphertext }
        let header = prefix + tail
        let length = tail.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard length > 0 else { throw AppSecurityError.invalidCiphertext }
        var remaining = length
        var position: UInt64 = 0
        var hash = SHA256()
        while remaining > 0 {
            try Task.checkCancellation()
            let count = Int(min(remaining, UInt64(chunkSize)))
            let encrypted = try input.read(upToCount: count + 28) ?? Data()
            guard encrypted.count == count + 28 else { throw AppSecurityError.invalidCiphertext }
            let box = try AES.GCM.SealedBox(combined: encrypted)
            let bytes = try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: header + number(position))
            guard bytes.count == count else { throw AppSecurityError.invalidCiphertext }
            try consume(bytes)
            hash.update(data: bytes)
            remaining -= UInt64(count)
            position += 1
        }
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw AppSecurityError.invalidCiphertext }
        return hex(hash.finalize())
    }

    private static func number(_ value: UInt64) -> Data {
        var big = value.bigEndian
        return withUnsafeBytes(of: &big) { Data($0) }
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
