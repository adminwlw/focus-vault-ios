import XCTest
import UIKit
import AVFoundation
@testable import FocusVault

@MainActor
final class VaultUpgradeTests: XCTestCase {
    private func photo(_ color: UIColor = .purple) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).pngData { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }

    func testFileImportDeduplicatesPersistsMetadataAndRestoresTrash() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let key = try CryptoBox.randomData(count: 32)
        let store = VaultStore(directory: root.appendingPathComponent("vault"))
        try store.unlock(using: key)
        defer { store.lock() }
        let source = root.appendingPathComponent("original.png")
        let bytes = photo()
        try bytes.write(to: source)
        let first = try await store.importFile(source, kind: .photo, album: "生活", sourceIdentifier: "source-photo")
        XCTAssertFalse(first.duplicate)
        XCTAssertEqual(store.items[0].isChunked, true)
        try store.editMetadata(first.id, name: "周末", note: "海边散步")
        try store.moveToTrash(store.items[0])
        let again = try await store.importFile(source, kind: .photo, album: "家人", sourceIdentifier: "source-photo")
        XCTAssertTrue(again.duplicate)
        XCTAssertEqual(again.id, first.id)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.activeItems.count, 1)
        store.lock()
        try store.unlock(using: key)
        XCTAssertEqual(store.items[0].title, "周末")
        XCTAssertEqual(store.items[0].note, "海边散步")
        XCTAssertEqual(store.items[0].albumName, "家人")
        XCTAssertEqual(store.items[0].originalState, .kept)
        XCTAssertEqual(store.pendingOriginalItems.count, 1)
        XCTAssertEqual(try store.data(for: store.items[0]), bytes)
        let exported = try await store.exportFiles([first.id])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(exported.first)), bytes)
    }

    func testLegacyFingerprintIsComparedBeforeAddingDuplicate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let key = try CryptoBox.randomData(count: 32)
        let store = VaultStore(directory: root)
        try store.unlock(using: key)
        defer { store.lock(); try? FileManager.default.removeItem(at: root) }
        let bytes = photo()
        try store.importData(bytes, kind: .photo, originalName: "legacy.png")
        var legacy = store.items[0]
        legacy.contentDigest = nil
        try CryptoBox.seal(JSONEncoder().encode([legacy]), using: key).write(to: root.appendingPathComponent("index.vault"))
        store.lock()
        try store.unlock(using: key)
        let source = root.appendingPathComponent("again.png")
        try bytes.write(to: source)
        let result = try await store.importFile(source, kind: .photo)
        XCTAssertTrue(result.duplicate)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotNil(store.items[0].contentDigest)
    }

    func testExistingBackupCanRestoreNewFileFormatWithoutReusingSystemIdentifiers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = VaultStore(directory: root.appendingPathComponent("first"))
        try store.unlock(using: CryptoBox.randomData(count: 32))
        defer { store.lock(); try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.png")
        let bytes = photo()
        try bytes.write(to: source)
        _ = try await store.importFile(source, kind: .photo, sourceIdentifier: "first-device-source")
        let backup = try store.createBackup(password: "existing-backup-password")
        let saved = root.appendingPathComponent("saved.focusvault")
        try Data(contentsOf: backup).write(to: saved)
        let second = VaultStore(directory: root.appendingPathComponent("second"))
        try second.unlock(using: CryptoBox.randomData(count: 32))
        defer { second.lock() }
        try second.restoreBackup(from: saved, password: "existing-backup-password")
        let item = try XCTUnwrap(second.items.first)
        XCTAssertNil(item.isChunked)
        XCTAssertNil(item.sourceIdentifier)
        XCTAssertEqual(item.originalState, .unknown)
        XCTAssertEqual(try second.data(for: item), bytes)
    }

    func testFailedFileCommitRemovesStagedMedia() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = VaultStore(directory: root)
        try store.unlock(using: CryptoBox.randomData(count: 32))
        defer { store.lock(); try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("index.vault"), withIntermediateDirectories: true)
        let source = root.appendingPathComponent("sample.png")
        try photo().write(to: source)
        do { _ = try await store.importFile(source, kind: .photo); XCTFail("Must reject failed index commit") }
        catch {}
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Media").path).isEmpty)
    }

    func testSearchDatesNotesAndMetadataValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = VaultStore(directory: root)
        try store.unlock(using: CryptoBox.randomData(count: 32))
        defer { store.lock(); try? FileManager.default.removeItem(at: root) }
        try store.importData(photo(), kind: .photo, originalName: "source.png", album: "旅行")
        let id = store.items[0].id
        try store.editMetadata(id, name: "海边", note: "周末散步")
        let item = store.items[0]
        XCTAssertTrue(item.matches(query: "周末", dateScope: .all))
        XCTAssertTrue(item.matches(query: "旅行", dateScope: .week))
        XCTAssertFalse(item.matches(query: "工作", dateScope: .all))
        XCTAssertFalse(item.matches(query: "", dateScope: .all, day: Date().addingTimeInterval(-5 * 86_400)))
        XCTAssertFalse(item.matches(query: "", dateScope: .week, now: Date().addingTimeInterval(20 * 86_400)))
        XCTAssertThrowsError(try store.editMetadata(id, name: String(repeating: "长", count: 81), note: ""))
        XCTAssertEqual(store.items[0].title, "海边")
    }

    func testDamagedStoredFileCannotRequestOriginalDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = VaultStore(directory: root)
        try store.unlock(using: CryptoBox.randomData(count: 32))
        defer { store.lock(); try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("sample.png")
        try photo().write(to: source)
        let item = try await store.importFile(source, kind: .photo, sourceIdentifier: "fake-source")
        let encrypted = root.appendingPathComponent("Media/\(item.id.uuidString).vault")
        try Data("damaged".utf8).write(to: encrypted)
        do { try await store.deleteOriginals(for: [item.id]); XCTFail("Must fail before requesting Photos authorization") }
        catch {}
        XCTAssertEqual(store.items[0].originalState, .kept)
    }

    func testVideoStartsPausedAndMuted() {
        let player = VaultPlayback.makePlayer(url: URL(fileURLWithPath: "/unused-test.mov"))
        XCTAssertTrue(player.isMuted)
        XCTAssertEqual(player.rate, 0)
    }

    func testChunkedFilesRejectTamperingTruncationAndWrongKey() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.bin")
        let encrypted = root.appendingPathComponent("encrypted.vault")
        let key = try CryptoBox.randomData(count: 32)
        let bytes = Data(repeating: 37, count: 2_097_159)
        try bytes.write(to: source)
        let fingerprint = try VaultMediaFile.encrypt(source, to: encrypted, key: key)
        XCTAssertEqual(try VaultMediaFile.digest(source), fingerprint)
        XCTAssertEqual(try VaultMediaFile.data(encrypted, key: key), bytes)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: CryptoBox.randomData(count: 32)))
        let valid = try Data(contentsOf: encrypted)
        var corrupted = valid
        corrupted[50] ^= 1
        try corrupted.write(to: encrypted)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: key))
        try Data(valid.dropLast()).write(to: encrypted)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: key))
        try (valid + Data([0])).write(to: encrypted)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: key))
        var changedHeader = valid
        changedHeader[16] ^= 1
        try changedHeader.write(to: encrypted)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: key))
        var changedMagic = valid
        changedMagic[0] ^= 1
        try changedMagic.write(to: encrypted)
        XCTAssertThrowsError(try VaultMediaFile.decryptedDigest(encrypted, key: key, requireChunked: true))
        let output = root.appendingPathComponent("output.bin")
        XCTAssertThrowsError(try VaultMediaFile.decrypt(encrypted, to: output, key: key))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testOneGiBFileRoundTripWithoutWholeFileBuffers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("one-gib.bin")
        try Data().write(to: source)
        let output = try FileHandle(forWritingTo: source)
        let block = Data(repeating: 73, count: 1_048_576)
        for _ in 0..<1_024 { try output.write(contentsOf: block) }
        try output.close()
        let key = try CryptoBox.randomData(count: 32)
        let encrypted = root.appendingPathComponent("encrypted.vault")
        let restored = root.appendingPathComponent("restored.bin")
        let fingerprint = try await VaultMediaFile.run {
            let hash = try VaultMediaFile.encrypt(source, to: encrypted, key: key)
            try VaultMediaFile.decrypt(encrypted, to: restored, key: key)
            return hash
        }
        let restoredDigest = try await VaultMediaFile.run { try VaultMediaFile.digest(restored) }
        XCTAssertEqual(try restored.resourceValues(forKeys: [.fileSizeKey]).fileSize, 1_073_741_824)
        XCTAssertEqual(restoredDigest, fingerprint)
    }

    func testCancelledFileOperationDoesNotPublishOutput() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.bin")
        let destination = root.appendingPathComponent("destination.vault")
        try Data(repeating: 12, count: 2_097_152).write(to: source)
        let key = try CryptoBox.randomData(count: 32)
        let operation = Task {
            try await VaultMediaFile.run { try VaultMediaFile.encrypt(source, to: destination, key: key) }
        }
        operation.cancel()
        do { _ = try await operation.value; XCTFail("Cancelled operation must not succeed") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}
