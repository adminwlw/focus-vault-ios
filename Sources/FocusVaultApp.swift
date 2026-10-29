import SwiftUI

@main
struct FocusVaultApp: App {
    @StateObject private var timerStore = FocusTimerStore()
    @StateObject private var authStore = VaultAuthStore()
    @StateObject private var vaultStore = VaultStore()

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

