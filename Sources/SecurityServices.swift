import CommonCrypto
import CryptoKit
import Foundation
import Security

enum AppSecurityError: LocalizedError {
    case keychain(OSStatus)
    case invalidCiphertext
    case invalidBackup
    case unsupportedBackup
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "系统钥匙串操作失败（\(status)）。"
        case .invalidCiphertext:
            return "加密数据已损坏或无法读取。"
        case .invalidBackup:
            return "这不是有效的私人空间备份。"
        case .unsupportedBackup:
            return "此备份版本暂不受支持。"
        case .wrongPassword:
            return "备份密码不正确或文件已损坏。"
        }
    }
}

enum SecureStore {
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.sim360.focusvault"
    }

    static func set(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw AppSecurityError.keychain(status) }
    }

    static func get(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppSecurityError.keychain(status)
        }
        return data
    }

    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppSecurityError.keychain(status)
        }
    }
}

enum CryptoBox {
    static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw AppSecurityError.keychain(status) }
        return data
    }

    static func seal(_ data: Data, using keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw AppSecurityError.invalidCiphertext }
        return combined
    }

    static func open(_ data: Data, using keyData: Data) throws -> Data {
        do {
            let sealed = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealed, using: SymmetricKey(data: keyData))
        } catch {
            throw AppSecurityError.invalidCiphertext
        }
    }

    static func passcodeDigest(passcode: String, salt: Data) -> Data {
        var input = Data(passcode.utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }

    static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func backupKey(password: String, salt: Data, iterations: Int) throws -> Data {
        var derived = [UInt8](repeating: 0, count: 32)
        let status: Int32 = password.withCString { passwordPointer in
            salt.withUnsafeBytes { saltPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPointer,
                    password.utf8.count,
                    saltPointer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived,
                    derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw AppSecurityError.invalidBackup }
        return Data(derived)
    }
}

@MainActor
final class VaultAuthStore: ObservableObject {
    private struct AuthRecord: Codable {
        let salt: Data
        let digest: Data
    }

    private let authAccount = "vault-auth-v1"
    private let keyAccount = "vault-key-v1"
    private let hintKey = "vault-passcode-hint"
    private var failedAttempts = 0
    private var nextAllowedAttempt = Date.distantPast

    @Published private(set) var isUnlocked = false
    @Published private(set) var lastError: String?

    var hasVault: Bool {
        (try? SecureStore.get(account: authAccount)) != nil
    }

    var hint: String {
        UserDefaults.standard.string(forKey: hintKey) ?? ""
    }

    func create(passcode: String, confirmation: String, hint: String) throws {
        guard passcode == confirmation else {
            throw ValidationError("两次输入的口令不一致。")
        }
        guard passcode.count >= 6 else {
            throw ValidationError("口令至少需要 6 个字符。")
        }
        guard !hint.isEmpty ? !hint.localizedCaseInsensitiveContains(passcode) : true else {
            throw ValidationError("提示词不能包含完整口令。")
        }

        let salt = try CryptoBox.randomData(count: 16)
        let record = AuthRecord(salt: salt, digest: CryptoBox.passcodeDigest(passcode: passcode, salt: salt))
        try SecureStore.set(try JSONEncoder().encode(record), account: authAccount)
        try SecureStore.set(try CryptoBox.randomData(count: 32), account: keyAccount)
        UserDefaults.standard.set(hint, forKey: hintKey)
        isUnlocked = true
        failedAttempts = 0
    }

    func verify(_ passcode: String, quietly: Bool = false) -> Bool {
        guard Date() >= nextAllowedAttempt else { return false }
        do {
            guard
                let data = try SecureStore.get(account: authAccount),
                let record = try? JSONDecoder().decode(AuthRecord.self, from: data)
            else { return false }

            let matches = CryptoBox.constantTimeEqual(
                CryptoBox.passcodeDigest(passcode: passcode, salt: record.salt),
                record.digest
            )
            if matches {
                isUnlocked = true
                failedAttempts = 0
                lastError = nil
                return true
            }

            failedAttempts += 1
            if failedAttempts >= 5 {
                let delay = min(pow(2.0, Double(failedAttempts - 5)), 30)
                nextAllowedAttempt = Date().addingTimeInterval(delay)
            }
            if !quietly { lastError = "口令不正确。" }
            return false
        } catch {
            if !quietly { lastError = error.localizedDescription }
            return false
        }
    }

    func changePasscode(current: String, new: String, confirmation: String, hint: String) throws {
        guard verify(current) else { throw ValidationError("当前口令不正确。") }
        guard new == confirmation, new.count >= 6 else {
            throw ValidationError("新口令至少需要 6 个字符，并且两次输入必须一致。")
        }
        let salt = try CryptoBox.randomData(count: 16)
        let record = AuthRecord(salt: salt, digest: CryptoBox.passcodeDigest(passcode: new, salt: salt))
        try SecureStore.set(try JSONEncoder().encode(record), account: authAccount)
        UserDefaults.standard.set(hint, forKey: hintKey)
    }

    func lock() {
        isUnlocked = false
        lastError = nil
    }

    func vaultKey() throws -> Data {
        guard isUnlocked, let key = try SecureStore.get(account: keyAccount) else {
            throw ValidationError("私人空间尚未解锁。")
        }
        return key
    }
}

struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

