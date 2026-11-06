import Foundation
import LocalAuthentication
import Security

enum BiometricVaultKey {
    private static let account = "vault-biometric-key-v1"
    private static var service: String { Bundle.main.bundleIdentifier ?? "com.sim360.focusvault" }

    static var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static func enable(_ key: Data) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                             localizedReason: "启用私人空间快捷认证")
        guard let control = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                            .biometryCurrentSet, nil) else {
            throw ValidationError("设备无法启用生物认证。")
        }
        try disable()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: control,
            kSecValueData as String: key,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AppSecurityError.keychain(status) }
    }

    static func read() async throws -> Data {
        try await VaultMediaFile.run {
            let context = LAContext()
            context.localizedCancelTitle = "取消"
            context.localizedFallbackTitle = ""
            context.localizedReason = "认证以打开私人空间"
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else {
                throw AppSecurityError.keychain(status)
            }
            return data
        }
    }

    static func disable() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AppSecurityError.keychain(status) }
    }
}
