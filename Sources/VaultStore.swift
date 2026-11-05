import Foundation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

@MainActor
final class VaultStore: ObservableObject {
    private let fileManager: FileManager
    private let rootURL: URL
    private let mediaURL: URL
    private let thumbnailURL: URL
    private let indexURL: URL
    private let exportURL: URL
    private var keyData: Data?
    private var sessionID = UUID()

    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var albums: [String] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = directory ?? applicationSupport.appendingPathComponent("PrivateVault", isDirectory: true)
        mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        thumbnailURL = rootURL.appendingPathComponent("Thumbnails", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("index.vault")
        exportURL = fileManager.temporaryDirectory.appendingPathComponent("FocusVaultExports", isDirectory: true)
        try? fileManager.removeItem(at: exportURL)
    }

    var activeItems: [VaultItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.importedAt > $1.importedAt }
    }

    var deletedItems: [VaultItem] {
        items.filter { $0.deletedAt != nil }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    func unlock(using key: Data) throws {
        lock()
        do {
            sessionID = UUID()
            keyData = key
            try prepareDirectories()
            if fileManager.fileExists(atPath: indexURL.path) {
                let encrypted = try Data(contentsOf: indexURL)
                let plaintext = try CryptoBox.open(encrypted, using: key)
                if let index = try? JSONDecoder().decode(VaultIndex.self, from: plaintext) {
                    guard index.version == 2 else { throw ValidationError("相册数据版本暂不受支持。") }
                    items = index.items
                    albums = index.albums
                } else {
                    items = try JSONDecoder().decode([VaultItem].self, from: plaintext)
                    albums = Array(Set(items.compactMap(\.albumName))).sorted()
                }
            } else {
                items = []
                albums = []
            }
            try purgeExpiredTrash()
            try cleanupOrphanedMedia()
            isLoaded = true
        } catch {
            lock()
            throw error
        }
    }

    func lock() {
        sessionID = UUID()
        items = []
        albums = []
        keyData = nil
        isLoaded = false
        errorMessage = nil
        try? fileManager.removeItem(at: exportURL)
    }

    func importSelections(_ selections: [PhotosPickerItem], toAlbum album: String? = nil) async -> [String] {
        guard !selections.isEmpty, isLoaded, !isBusy else { return [] }
        let importSession = sessionID
        isBusy = true
        defer { isBusy = false }
        var failures = 0
        var importedAssetIdentifiers: [String] = []

        for selection in selections {
            guard isLoaded, sessionID == importSession, !Task.isCancelled else { return [] }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    failures += 1
                    continue
                }
                guard isLoaded, sessionID == importSession, !Task.isCancelled else { return [] }
                let kind: VaultMediaKind = selection.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
                    ? .video
                    : .photo
                let fileExtension = selection.supportedContentTypes.first?.preferredFilenameExtension
                    ?? (kind == .photo ? "jpg" : "mov")
                let capturedAt = kind == .photo ? capturedDate(from: data) : nil
                try importData(
                    data,
                    kind: kind,
                    originalName: "导入项目.\(fileExtension)",
                    capturedAt: capturedAt,
                    album: album
                )
                if let identifier = selection.itemIdentifier {
                    importedAssetIdentifiers.append(identifier)
                }
            } catch {
                failures += 1
            }
        }
        if failures > 0, isLoaded {
            errorMessage = "有 \(failures) 个项目未能导入，已成功的项目不受影响。"
        }
        return importedAssetIdentifiers
    }

    func requestPhotoLibraryReadWriteAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let status: PHAuthorizationStatus
        if current == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            status = current
        }
        return status == .authorized || status == .limited
    }

    func deleteSystemAssets(localIdentifiers: [String]) async throws {
        let identifiers = Array(Set(localIdentifiers))
        guard !identifiers.isEmpty else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ValidationError("没有照片库修改权限，系统原件已保留。")
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count == identifiers.count else {
            throw ValidationError("部分系统原件已无法定位。为避免误删，本次没有删除任何项目。")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ValidationError("系统未完成删除，原件已保留。"))
                }
            }
        }
    }

    func importCapturedImage(_ image: UIImage, toAlbum album: String? = nil) throws {
        guard let data = image.jpegData(compressionQuality: 0.94) else {
            throw ValidationError("无法读取刚拍摄的照片。")
        }
        try importData(data, kind: .photo, originalName: "相机拍摄.jpg", capturedAt: Date(), album: album)
    }

    func importData(
        _ data: Data,
        kind: VaultMediaKind,
        originalName: String,
        capturedAt: Date? = nil,
        album: String? = nil
    ) throws {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        guard !data.isEmpty else { throw ValidationError("导入项目为空。") }
        let decodedImage = kind == .photo ? UIImage(data: data) : nil
        if kind == .photo, decodedImage == nil { throw ValidationError("照片格式无法读取。") }
        let item = VaultItem(
            id: UUID(),
            originalName: originalName,
            importedAt: Date(),
            capturedAt: capturedAt,
            mediaKind: kind,
            byteCount: data.count,
            albumName: album,
            isFavorite: false,
            deletedAt: nil
        )
        let encrypted = try CryptoBox.seal(data, using: keyData)
        let mediaFile = mediaFileURL(for: item.id)
        do {
            try protectedWrite(encrypted, to: mediaFile)
            let stored = try CryptoBox.open(Data(contentsOf: mediaFile), using: keyData)
            guard stored == data else { throw ValidationError("写入后的媒体校验失败。") }
            if let decodedImage, let thumbnail = thumbnailData(from: decodedImage) {
                try protectedWrite(
                    try CryptoBox.seal(thumbnail, using: keyData),
                    to: thumbnailFileURL(for: item.id)
                )
            }
            if kind == .video { try createVideoThumbnail(data, id: item.id, key: keyData) }
            try commit(items + [item], albums: albums + (album.map { [$0] } ?? []))
        } catch {
            try? fileManager.removeItem(at: mediaFile)
            try? fileManager.removeItem(at: thumbnailFileURL(for: item.id))
            throw error
        }
    }

    func data(for item: VaultItem) throws -> Data {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let encrypted = try Data(contentsOf: mediaFileURL(for: item.id))
        return try CryptoBox.open(encrypted, using: keyData)
    }

    func thumbnailData(for item: VaultItem) throws -> Data {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let url = thumbnailFileURL(for: item.id)
        guard fileManager.fileExists(atPath: url.path) else {
            if item.mediaKind == .video { throw ValidationError("视频尚无预览图。") }
            return try data(for: item)
        }
        return try CryptoBox.open(Data(contentsOf: url), using: keyData)
    }

    func temporaryExport(for item: VaultItem) throws -> URL {
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        let safeName = URL(fileURLWithPath: item.originalName).lastPathComponent
        let url = exportURL.appendingPathComponent("\(item.id.uuidString)-\(safeName)")
        try protectedWrite(try data(for: item), to: url)
        return url
    }

    func cleanupTemporaryExports() {
        try? fileManager.removeItem(at: exportURL)
    }

    func toggleFavorite(_ item: VaultItem) throws {
        try update(item.id) { $0.isFavorite.toggle() }
    }

    func assign(_ item: VaultItem, toAlbum album: String?) throws {
        try assign([item.id], toAlbum: album)
    }

    func assign(_ ids: Set<UUID>, toAlbum album: String?) throws {
        let cleaned = try album.map { try validAlbumName($0) }
        var updated = items
        for index in updated.indices where ids.contains(updated[index].id) {
            updated[index].albumName = cleaned
        }
        try commit(updated, albums: albums + (cleaned.map { [$0] } ?? []))
    }

    @discardableResult
    func createAlbum(_ name: String, moving ids: Set<UUID> = []) throws -> String {
        let cleaned = try validAlbumName(name)
        guard !albums.contains(where: { $0.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            throw ValidationError("已存在同名相册，请换一个名称。")
        }
        try assign(ids, toAlbum: cleaned)
        return cleaned
    }

    func renameAlbum(_ name: String, to newName: String) throws {
        let cleaned = try validAlbumName(newName)
        guard albums.contains(name) else { throw ValidationError("相册不存在。") }
        guard !albums.contains(where: { $0 != name && $0.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            throw ValidationError("已存在同名相册。")
        }
        var updated = items
        for index in updated.indices where updated[index].albumName == name { updated[index].albumName = cleaned }
        try commit(updated, albums: albums.map { $0 == name ? cleaned : $0 })
    }

    func deleteAlbum(_ name: String) throws {
        var updated = items
        for index in updated.indices where updated[index].albumName == name { updated[index].albumName = nil }
        try commit(updated, albums: albums.filter { $0 != name })
    }

    private func validAlbumName(_ name: String) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 40, !cleaned.contains(where: \.isNewline) else {
            throw ValidationError("相册名称请输入 1–40 个字符。")
        }
        return cleaned
    }

    func setFavorite(_ ids: Set<UUID>, value: Bool) throws {
        var updated = items
        for index in updated.indices where ids.contains(updated[index].id) {
            updated[index].isFavorite = value
        }
        try commit(updated, albums: albums)
    }

    func moveToTrash(_ item: VaultItem) throws {
        try update(item.id) { $0.deletedAt = Date() }
    }

    func moveToTrash(_ ids: Set<UUID>) throws {
        let deletedAt = Date()
        var updated = items
        for index in updated.indices where ids.contains(updated[index].id) {
            updated[index].deletedAt = deletedAt
        }
        try commit(updated, albums: albums)
    }

    func restore(_ item: VaultItem) throws {
        try update(item.id) { $0.deletedAt = nil }
    }

    func deletePermanently(_ item: VaultItem) throws {
        try removePermanently([item])
    }

    func emptyTrash() throws {
        try removePermanently(deletedItems)
    }

    func restoreAllTrash() throws {
        var updated = items
        for index in updated.indices { updated[index].deletedAt = nil }
        try commit(updated, albums: albums)
    }

    private func removePermanently(_ removing: [VaultItem]) throws {
        let ids = Set(removing.map(\.id))
        guard removing.allSatisfy({ $0.deletedAt != nil }) else { throw ValidationError("请先移到最近删除。") }
        // Persist the index first; a failed index write must never destroy referenced media.
        try commit(items.filter { !ids.contains($0.id) }, albums: albums)
        var failed = false
        for item in removing {
            for url in [mediaFileURL(for: item.id), thumbnailFileURL(for: item.id)] where fileManager.fileExists(atPath: url.path) {
                do { try fileManager.removeItem(at: url) } catch { failed = true }
            }
        }
        if failed { throw ValidationError("项目已移出列表，部分加密文件未能清理；下次解锁时会重试。") }
    }

    private func cleanupOrphanedMedia() throws {
        let retained = Set(items.map { $0.id.uuidString + ".vault" })
        for directory in [mediaURL, thumbnailURL] {
            for url in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                where url.pathExtension == "vault" && !retained.contains(url.lastPathComponent) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    func createBackup(password: String) throws -> URL {
        guard password.count >= 8 else { throw ValidationError("备份密码至少需要 8 个字符。") }
        guard items.reduce(Int64(0), { $0 + Int64($1.byteCount) }) <= 256 * 1_024 * 1_024 else {
            throw ValidationError("本版单个备份最多支持 256 MB 媒体，请先分别导出大视频。")
        }
        let payload = VaultBackupPayload(
            version: 1,
            createdAt: Date(),
            items: items,
            media: try Dictionary(uniqueKeysWithValues: items.map { item in
                (item.id.uuidString, try data(for: item))
            }),
            albums: albums
        )
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = exportURL.appendingPathComponent("私人空间备份-\(formatter.string(from: Date())).focusvault")
        // shortcut: the v1 backup is assembled in memory; stream a future format before supporting very large video libraries.
        try protectedWrite(try BackupCodec.encode(payload, password: password), to: url)
        return url
    }

    func restoreBackup(from url: URL, password: String) throws {
        guard let keyData else { throw ValidationError("请先解锁私人空间。") }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= 512 * 1_024 * 1_024 else { throw ValidationError("备份文件过大，本版暂不支持恢复。") }
        let payload = try BackupCodec.decode(Data(contentsOf: url), password: password)
        guard Set(payload.items.map(\.id)).count == payload.items.count else { throw AppSecurityError.invalidBackup }
        // Validate every entry before touching any existing file, including duplicate IDs.
        for item in payload.items {
            guard let original = payload.media[item.id.uuidString], !original.isEmpty,
                  original.count == item.byteCount else { throw AppSecurityError.invalidBackup }
            if item.mediaKind == .photo, UIImage(data: original) == nil { throw AppSecurityError.invalidBackup }
            if let album = item.albumName { _ = try validAlbumName(album) }
        }
        for album in payload.albums ?? [] { _ = try validAlbumName(album) }
        let existingIDs = Set(items.map(\.id))
        let incoming = payload.items.filter { !existingIDs.contains($0.id) }
        var written: [UUID] = []
        do {
            for item in incoming {
                let original = payload.media[item.id.uuidString]!
                written.append(item.id)
                try protectedWrite(try CryptoBox.seal(original, using: keyData), to: mediaFileURL(for: item.id))
                if item.mediaKind == .photo, let image = UIImage(data: original), let thumbnail = thumbnailData(from: image) {
                    try protectedWrite(try CryptoBox.seal(thumbnail, using: keyData), to: thumbnailFileURL(for: item.id))
                } else if item.mediaKind == .video {
                    try createVideoThumbnail(original, id: item.id, key: keyData)
                }
            }
            try commit(items + incoming, albums: albums + (payload.albums ?? []) + incoming.compactMap(\.albumName))
        } catch {
            for id in written {
                try? fileManager.removeItem(at: mediaFileURL(for: id))
                try? fileManager.removeItem(at: thumbnailFileURL(for: id))
            }
            throw error
        }
    }

    private func update(_ id: UUID, mutation: (inout VaultItem) -> Void) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updated = items
        mutation(&updated[index])
        try commit(updated, albums: albums)
    }

    private func commit(_ updated: [VaultItem], albums updatedAlbums: [String]) throws {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let sortedAlbums = Array(Set(updatedAlbums)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let plaintext = try JSONEncoder().encode(VaultIndex(items: updated, albums: sortedAlbums))
        try protectedWrite(try CryptoBox.seal(plaintext, using: keyData), to: indexURL)
        items = updated
        albums = sortedAlbums
    }

    private func purgeExpiredTrash() throws {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let expired = items.filter { ($0.deletedAt ?? .distantFuture) < cutoff }
        guard !expired.isEmpty else { return }
        try removePermanently(expired)
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: rootURL.path)
        var root = rootURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
    }

    private func protectedWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    private func mediaFileURL(for id: UUID) -> URL {
        mediaURL.appendingPathComponent("\(id.uuidString).vault")
    }

    private func thumbnailFileURL(for id: UUID) -> URL {
        thumbnailURL.appendingPathComponent("\(id.uuidString).vault")
    }

    private func thumbnailData(from image: UIImage) -> Data? {
        let maximum: CGFloat = 512
        let ratio = min(maximum / image.size.width, maximum / image.size.height, 1)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.82) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func createVideoThumbnail(_ data: Data, id: UUID, key: Data) throws {
        let url = exportURL.appendingPathComponent("\(id.uuidString).mov")
        try protectedWrite(data, to: url)
        defer { try? fileManager.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        // A missing preview does not invalidate a successfully copied video.
        if let frame = try? generator.copyCGImage(at: .zero, actualTime: nil),
           let thumbnail = UIImage(cgImage: frame).jpegData(compressionQuality: 0.82) {
            try protectedWrite(try CryptoBox.seal(thumbnail, using: key), to: thumbnailFileURL(for: id))
        }
    }

    private func capturedDate(from data: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let value = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
