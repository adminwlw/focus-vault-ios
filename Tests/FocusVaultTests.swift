import XCTest
@testable import FocusVault

final class FocusVaultTests: XCTestCase {
    @MainActor
    func testVaultAuthCreateLockAndVerify() throws {
        try? SecureStore.delete(account: "vault-auth-v1")
        try? SecureStore.delete(account: "vault-key-v1")
        defer {
            try? SecureStore.delete(account: "vault-auth-v1")
            try? SecureStore.delete(account: "vault-key-v1")
        }

        let store = VaultAuthStore()
        try store.create(passcode: "vault123", confirmation: "vault123", hint: "")
        store.lock()

        XCTAssertFalse(store.verify("wrong-password", quietly: true))
        XCTAssertTrue(store.verify("vault123", quietly: true))
    }

    func testAESRoundTrip() throws {
        let key = try CryptoBox.randomData(count: 32)
        let original = Data("private photo bytes".utf8)
        let encrypted = try CryptoBox.seal(original, using: key)

        XCTAssertNotEqual(encrypted, original)
        XCTAssertEqual(try CryptoBox.open(encrypted, using: key), original)
    }

    func testAESRejectsWrongKey() throws {
        let encrypted = try CryptoBox.seal(
            Data("secret".utf8),
            using: CryptoBox.randomData(count: 32)
        )
        let wrongKey = try CryptoBox.randomData(count: 32)

        XCTAssertThrowsError(try CryptoBox.open(encrypted, using: wrongKey))
    }

    func testBackupKeyDerivationIsDeterministic() throws {
        let salt = Data(repeating: 3, count: 16)
        let first = try CryptoBox.backupKey(password: "backup-password", salt: salt, iterations: 1_000)
        let second = try CryptoBox.backupKey(password: "backup-password", salt: salt, iterations: 1_000)
        let different = try CryptoBox.backupKey(password: "different", salt: salt, iterations: 1_000)

        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testTimerStateRoundTrip() throws {
        let original = FocusTimerState(
            taskName: "写方案",
            plannedSeconds: 1_500,
            remainingWhenPaused: 900,
            endDate: Date(timeIntervalSince1970: 1_800_000_000),
            startedAt: Date(timeIntervalSince1970: 1_799_999_100),
            phase: .paused,
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        )
        let restored = try JSONDecoder().decode(
            FocusTimerState.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(restored, original)
    }

    func testBackupCodecRoundTripAndTamperRejection() throws {
        let item = VaultItem(
            id: UUID(),
            originalName: "sample.jpg",
            importedAt: Date(timeIntervalSince1970: 1_800_000_000),
            capturedAt: nil,
            mediaKind: .photo,
            byteCount: 3,
            albumName: "家人",
            isFavorite: true,
            deletedAt: nil
        )
        let payload = VaultBackupPayload(
            version: 1,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            items: [item],
            media: [item.id.uuidString: Data([1, 2, 3])]
        )
        let encoded = try BackupCodec.encode(payload, password: "backup-password", iterations: 1_000)
        let decoded = try BackupCodec.decode(encoded, password: "backup-password")
        XCTAssertEqual(decoded.items, payload.items)
        XCTAssertEqual(decoded.media, payload.media)

        var tampered = encoded
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        XCTAssertThrowsError(try BackupCodec.decode(tampered, password: "backup-password"))
    }
}

