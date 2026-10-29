import Foundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit

@MainActor
final class VaultStore: ObservableObject {
    private let fileManager: FileManager
    private let rootURL: URL
    private let mediaURL: URL
    private let indexURL: URL
    private let exportURL: URL
    private var keyData: Data?

    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = applicationSupport.appendingPathComponent("PrivateVault", isDirectory: true)
        mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("index.vault")
        exportURL = fileManager.temporaryDirectory.appendingPathComponent("FocusVaultExports", isDirectory: true)
    }

    var activeItems: [VaultItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.importedAt > $1.importedAt }
    }

    var deletedItems: [VaultItem] {
        items.filter { $0.deletedAt != nil }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var albums: [String] {
        Array(Set(activeItems.compactMap(\.albumName))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func unlock(using key: Data) throws {
        keyData = key
        try prepareDirectories()
        if fileManager.fileExists(atPath: indexURL.path) {
            let encrypted = try Data(contentsOf: indexURL)
            let plaintext = try CryptoBox.open(encrypted, using: key)
            items = try JSONDecoder().decode([VaultItem].self, from: plaintext)
        } else {
            items = []
        }
        try purgeExpiredTrash()
        isLoaded = true
    }

    func lock() {
        items = []
        keyData = nil
        isLoaded = false
        errorMessage = nil
        try? fileManager.removeItem(at: exportURL)
    }

    func importSelections(_ selections: [PhotosPickerItem]) async {
        guard !selections.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        var failures = 0

        for selection in selections {
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    failures += 1
                    continue
                }
                let kind: VaultMediaKind = selection.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
                    ? .video
                    : .photo
                let fileExtension = selection.supportedContentTypes.first?.preferredFilenameExtension
                    ?? (kind == .photo ? "jpg" : "mov")
                try importData(data, kind: kind, originalName: "导入项目.\(fileExtension)")
            } catch {
                failures += 1
            }
        }
        if failures > 0 {
            errorMessage = "有 \(failures) 个项目未能导入，已成功的项目不受影响。"
        }
    }

    func importCapturedImage(_ image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: 0.94) else {
            throw ValidationError("无法读取刚拍摄的照片。")
        }
        try importData(data, kind: .photo, originalName: "相机拍摄.jpg")
    }

    func importData(_ data: Data, kind: VaultMediaKind, originalName: String) throws {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let item = VaultItem(
            id: UUID(),
            originalName: originalName,
            importedAt: Date(),
            mediaKind: kind,
            byteCount: data.count,
            albumName: nil,
            isFavorite: false,
            deletedAt: nil
        )
        let encrypted = try CryptoBox.seal(data, using: keyData)
        try protectedWrite(encrypted, to: mediaFileURL(for: item.id))
        items.append(item)
        try saveIndex()
    }

    func data(for item: VaultItem) throws -> Data {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let encrypted = try Data(contentsOf: mediaFileURL(for: item.id))
        return try CryptoBox.open(encrypted, using: keyData)
    }

    func temporaryExport(for item: VaultItem) throws -> URL {
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        let safeName = item.originalName.replacingOccurrences(of: "/", with: "-")
        let url = exportURL.appendingPathComponent("\(item.id.uuidString)-\(safeName)")
        try protectedWrite(try data(for: item), to: url)
        return url
    }

    func toggleFavorite(_ item: VaultItem) throws {
        try update(item.id) { $0.isFavorite.toggle() }
    }

    func assign(_ item: VaultItem, toAlbum album: String?) throws {
        let cleaned = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        try update(item.id) { $0.albumName = cleaned?.isEmpty == true ? nil : cleaned }
    }

    func moveToTrash(_ item: VaultItem) throws {
        try update(item.id) { $0.deletedAt = Date() }
    }

    func restore(_ item: VaultItem) throws {
        try update(item.id) { $0.deletedAt = nil }
    }

    func deletePermanently(_ item: VaultItem) throws {
        try fileManager.removeItem(at: mediaFileURL(for: item.id))
        items.removeAll { $0.id == item.id }
        try saveIndex()
    }

    func emptyTrash() throws {
        for item in deletedItems {
            try? fileManager.removeItem(at: mediaFileURL(for: item.id))
        }
        items.removeAll { $0.deletedAt != nil }
        try saveIndex()
    }

    func createBackup(password: String) throws -> URL {
        guard password.count >= 8 else { throw ValidationError("备份密码至少需要 8 个字符。") }
        let payload = VaultBackupPayload(
            version: 1,
            createdAt: Date(),
            items: items,
            media: try Dictionary(uniqueKeysWithValues: items.map { item in
                (item.id.uuidString, try data(for: item))
            })
        )
        let payloadData = try JSONEncoder().encode(payload)
        let salt = try CryptoBox.randomData(count: 16)
        let iterations = 210_000
        let backupKey = try CryptoBox.backupKey(password: password, salt: salt, iterations: iterations)
        let envelope = VaultBackupEnvelope(
            format: "FocusVaultBackup",
            version: 1,
            salt: salt,
            iterations: iterations,
            encryptedPayload: try CryptoBox.seal(payloadData, using: backupKey)
        )
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = exportURL.appendingPathComponent("私人空间备份-\(formatter.string(from: Date())).focusvault")
        try protectedWrite(try JSONEncoder().encode(envelope), to: url)
        return url
    }

    func restoreBackup(from url: URL, password: String) throws {
        guard let keyData else { throw ValidationError("请先解锁私人空间。") }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let envelope: VaultBackupEnvelope
        do {
            envelope = try JSONDecoder().decode(VaultBackupEnvelope.self, from: Data(contentsOf: url))
        } catch {
            throw AppSecurityError.invalidBackup
        }
        guard envelope.format == "FocusVaultBackup" else { throw AppSecurityError.invalidBackup }
        guard envelope.version == 1 else { throw AppSecurityError.unsupportedBackup }

        let backupKey = try CryptoBox.backupKey(
            password: password,
            salt: envelope.salt,
            iterations: envelope.iterations
        )
        let payloadData: Data
        do {
            payloadData = try CryptoBox.open(envelope.encryptedPayload, using: backupKey)
        } catch {
            throw AppSecurityError.wrongPassword
        }
        let payload = try JSONDecoder().decode(VaultBackupPayload.self, from: payloadData)
        guard payload.version == 1 else { throw AppSecurityError.unsupportedBackup }

        for item in payload.items {
            guard let original = payload.media[item.id.uuidString] else { throw AppSecurityError.invalidBackup }
            try protectedWrite(try CryptoBox.seal(original, using: keyData), to: mediaFileURL(for: item.id))
        }
        let incomingIDs = Set(payload.items.map(\.id))
        items.removeAll { incomingIDs.contains($0.id) }
        items.append(contentsOf: payload.items)
        try saveIndex()
    }

    private func update(_ id: UUID, mutation: (inout VaultItem) -> Void) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutation(&items[index])
        try saveIndex()
    }

    private func saveIndex() throws {
        guard let keyData else { throw ValidationError("私人空间尚未解锁。") }
        let plaintext = try JSONEncoder().encode(items)
        try protectedWrite(try CryptoBox.seal(plaintext, using: keyData), to: indexURL)
    }

    private func purgeExpiredTrash() throws {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let expired = items.filter { ($0.deletedAt ?? .distantFuture) < cutoff }
        guard !expired.isEmpty else { return }
        for item in expired {
            try? fileManager.removeItem(at: mediaFileURL(for: item.id))
        }
        items.removeAll { item in expired.contains(where: { $0.id == item.id }) }
        try saveIndex()
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: rootURL.path)
    }

    private func protectedWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    private func mediaFileURL(for id: UUID) -> URL {
        mediaURL.appendingPathComponent("\(id.uuidString).vault")
    }
}
