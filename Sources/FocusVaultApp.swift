import SwiftUI

@main
@MainActor
struct FocusVaultApp: App {
    @StateObject private var timerStore: FocusTimerStore
    @StateObject private var authStore: VaultAuthStore
    @StateObject private var vaultStore: VaultStore

    init() {
        #if DEBUG
        UITestFixtures.resetIfRequested()
        #endif
        _timerStore = StateObject(wrappedValue: FocusTimerStore())
        _authStore = StateObject(wrappedValue: VaultAuthStore())
        _vaultStore = StateObject(wrappedValue: VaultStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(timerStore)
                .environmentObject(authStore)
                .environmentObject(vaultStore)
                .tint(.blue)
        }
    }
}

