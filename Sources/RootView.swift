import SwiftUI

struct RootView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    @EnvironmentObject private var vaultStore: VaultStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showVault = false
    @State private var showSetup = false
    @State private var vaultError: String?

    var body: some View {
        TabView {
            FocusView {
                openUnlockedVault()
            }
            .tabItem { Label("计时", systemImage: "timer") }

            StopwatchView()
            .tabItem { Label("秒表", systemImage: "stopwatch") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showSetup) {
            VaultSetupView(required: true) {
                authStore.lock()
                vaultStore.lock()
            }
        }
        .fullScreenCover(isPresented: $showVault, onDismiss: lockVault) {
            VaultView(onLock: lockVault)
                .privacySensitive()
        }
        .alert("无法打开私人空间", isPresented: Binding(
            get: { vaultError != nil },
            set: { if !$0 { vaultError = nil } }
        )) {
            Button("好", role: .cancel) { vaultError = nil }
        } message: {
            Text(vaultError ?? "未知错误")
        }
        .background(PrivacyScreen().frame(width: 0, height: 0))
        .onAppear {
            if !authStore.hasVault { showSetup = true }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                timerStore.refresh()
                Task { await timerStore.refreshNotificationStatus() }
            } else if newPhase == .background {
                lockVault()
            }
        }
    }

    private func openUnlockedVault() {
        guard authStore.isUnlocked else { return }
        do {
            try vaultStore.unlock(using: authStore.vaultKey())
            showSetup = false
            showVault = true
        } catch {
            authStore.lock()
            vaultStore.lock()
            vaultError = error.localizedDescription
        }
    }

    private func lockVault() {
        showVault = false
        authStore.lock()
        vaultStore.lock()
    }
}

