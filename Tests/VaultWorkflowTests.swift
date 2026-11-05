import XCTest
import UIKit
@testable import FocusVault

@MainActor
final class VaultWorkflowTests: XCTestCase {
    private var directory: URL!
    private var key: Data!
    private var store: VaultStore!

    private func prepare() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        key = try CryptoBox.randomData(count: 32)
        store = VaultStore(directory: directory)
        try store.unlock(using: key)
    }

    private func cleanup() {
        store.lock()
        try? FileManager.default.removeItem(at: directory)
    }

    private func photo() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).pngData { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    func testEmptyAlbumPersistsAndNamesAreValidated() throws {
        try prepare()
        defer { cleanup() }
        try store.createAlbum("  家人  ")
        XCTAssertThrowsError(try store.createAlbum("家人"))
        XCTAssertThrowsError(try store.createAlbum(" \n "))
        XCTAssertThrowsError(try store.createAlbum(String(repeating: "相", count: 41)))
        store.lock()
        try store.unlock(using: key)
        XCTAssertEqual(store.albums, ["家人"])
        XCTAssertTrue(store.items.isEmpty)
    }

    func testAlbumRenameDeleteRetainsPhotoAndTrashRestore() throws {
        try prepare()
        defer { cleanup() }
        let original = photo()
        try store.createAlbum("家人")
        try store.importData(original, kind: .photo, originalName: "sample.png", album: "家人")
        let item = try XCTUnwrap(store.items.first)
        try store.renameAlbum("家人", to: "生活")
        XCTAssertEqual(store.items.first?.albumName, "生活")
        try store.moveToTrash(item)
        XCTAssertTrue(store.activeItems.isEmpty)
        try store.deleteAlbum("生活")
        try store.restoreAllTrash()
        XCTAssertNil(store.items.first?.albumName)
        XCTAssertEqual(try store.data(for: item), original)
        XCTAssertThrowsError(try store.deletePermanently(store.items[0]))
        try store.moveToTrash(store.items[0])
        try store.emptyTrash()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testLegacyIndexMigratesWithoutLosingMedia() throws {
        try prepare()
        defer { cleanup() }
        try store.importData(photo(), kind: .photo, originalName: "old.png", album: "旧相册")
        let original = store.items
        let encrypted = try CryptoBox.seal(JSONEncoder().encode(original), using: key)
        try encrypted.write(to: directory.appendingPathComponent("index.vault"))
        store.lock()
        try store.unlock(using: key)
        XCTAssertEqual(store.items, original)
        XCTAssertEqual(store.albums, ["旧相册"])
        try store.createAlbum("新相册")
        store.lock()
        try store.unlock(using: key)
        XCTAssertEqual(store.items, original)
        XCTAssertEqual(Set(store.albums), ["旧相册", "新相册"])
    }

    func testFailedIndexWriteDoesNotPublishOrLeaveImportedMedia() throws {
        try prepare()
        defer { cleanup() }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("index.vault"), withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.importData(photo(), kind: .photo, originalName: "sample.png"))
        XCTAssertTrue(store.items.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Media").path)
        XCTAssertTrue(files.isEmpty)
        XCTAssertThrowsError(try store.createAlbum("失败相册"))
        XCTAssertTrue(store.albums.isEmpty)
    }

    func testBackupPreservesEmptyAlbumsAndDoesNotOverwriteExistingItem() throws {
        try prepare()
        defer { cleanup() }
        try store.createAlbum("空相册")
        try store.importData(photo(), kind: .photo, originalName: "sample.png")
        let url = try store.createBackup(password: "backup-password")
        let backup = try Data(contentsOf: url)
        try store.setFavorite([store.items[0].id], value: true)
        try store.deleteAlbum("空相册")
        // Repeated restore merges rather than reverting the newer local favorite state.
        try backup.write(to: url)
        try store.restoreBackup(from: url, password: "backup-password")
        try store.restoreBackup(from: url, password: "backup-password")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items[0].isFavorite)
        XCTAssertEqual(store.albums, ["空相册"])
    }

    func testInvalidBackupNeverChangesExistingFiles() throws {
        try prepare()
        defer { cleanup() }
        let original = photo()
        try store.importData(original, kind: .photo, originalName: "sample.png")
        let local = store.items[0]
        var missing = local
        missing.id = UUID()
        let payload = VaultBackupPayload(version: 1, createdAt: Date(), items: [local, missing], media: [local.id.uuidString: original])
        let url = directory.appendingPathComponent("invalid.focusvault")
        try BackupCodec.encode(payload, password: "backup-password", iterations: 1_000).write(to: url)
        XCTAssertThrowsError(try store.restoreBackup(from: url, password: "backup-password"))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(try store.data(for: local), original)
    }

    func testWrongKeyClearsLoadedContent() throws {
        try prepare()
        defer { cleanup() }
        try store.importData(photo(), kind: .photo, originalName: "sample.png")
        XCTAssertThrowsError(try store.unlock(using: CryptoBox.randomData(count: 32)))
        XCTAssertFalse(store.isLoaded)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.albums.isEmpty)
    }

    func testBackupRejectsInvalidWorkFactorBeforeDerivation() throws {
        let envelope = VaultBackupEnvelope(format: "FocusVaultBackup", version: 1,
                                          salt: Data(repeating: 0, count: 16), iterations: -1,
                                          encryptedPayload: Data())
        XCTAssertThrowsError(try BackupCodec.decode(JSONEncoder().encode(envelope), password: "password"))
    }

    func testStopwatchPauseResumeLapsAndRelaunch() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let watch = StopwatchStore(defaults: defaults, now: { now })
        watch.start()
        now.addTimeInterval(12.5)
        watch.lap()
        XCTAssertEqual(watch.state.laps, [12.5])
        watch.pause()
        now.addTimeInterval(300)
        XCTAssertEqual(watch.state.elapsed(at: now), 12.5)
        watch.start()
        now.addTimeInterval(7.5)
        let restored = StopwatchStore(defaults: defaults, now: { now })
        XCTAssertEqual(restored.state.elapsed(at: now), 20)
        restored.pause()
        restored.reset()
        XCTAssertEqual(restored.state.elapsed(at: now), 0)
        XCTAssertTrue(restored.state.laps.isEmpty)
    }
}
