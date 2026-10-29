import XCTest
@testable import FocusVault

final class FocusVaultTests: XCTestCase {
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

    func testPasscodeDigestIsSaltedAndDeterministic() throws {
        let salt = Data(repeating: 7, count: 16)
        let otherSalt = Data(repeating: 8, count: 16)

        XCTAssertEqual(
            CryptoBox.passcodeDigest(passcode: "12345678", salt: salt),
            CryptoBox.passcodeDigest(passcode: "12345678", salt: salt)
        )
        XCTAssertNotEqual(
            CryptoBox.passcodeDigest(passcode: "12345678", salt: salt),
            CryptoBox.passcodeDigest(passcode: "12345678", salt: otherSalt)
        )
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
            phase: .paused,
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        )
        let restored = try JSONDecoder().decode(
            FocusTimerState.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(restored, original)
    }
}

