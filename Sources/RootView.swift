import SwiftUI

struct RootView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    @EnvironmentObject private var vaultStore: VaultStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showVault = false
    @State private var showSetup = false
    @State private var showUnlock = false
    @State private var vaultError: String?

    var body: some View {
        TabView {
            FocusView()
                .tabItem { Label("专注", systemImage: "timer") }

            HistoryView {
                openUnlockedVault()
            }
            .tabItem { Label("记录", systemImage: "clock.arrow.circlepath") }

            SettingsView(openVault: openVault)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showSetup) {
            VaultSetupView {
                openUnlockedVault()
            }
        }
        .sheet(isPresented: $showUnlock) {
            VaultUnlockView {
                openUnlockedVault()
            }
        }
        .fullScreenCover(isPresented: $showVault, onDismiss: lockVault) {
            VaultView(onLock: lockVault)
        }
        .alert("无法打开私人空间", isPresented: Binding(
            get: { vaultError != nil },
            set: { if !$0 { vaultError = nil } }
        )) {
            Button("好", role: .cancel) { vaultError = nil }
        } message: {
            Text(vaultError ?? "未知错误")
        }
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Color(uiColor: .systemBackground)
                    Image(systemName: "timer")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                timerStore.refresh()
            } else {
                lockVault()
            }
        }
    }

    private func openVault() {
        if authStore.hasVault {
            if authStore.isUnlocked {
                openUnlockedVault()
            } else {
                showUnlock = true
            }
        } else {
            showSetup = true
        }
    }

    private func openUnlockedVault() {
        guard authStore.isUnlocked else { return }
        do {
            try vaultStore.unlock(using: authStore.vaultKey())
            showSetup = false
            showUnlock = false
            showVault = true
        } catch {
            vaultError = error.localizedDescription
        }
    }

    private func lockVault() {
        showVault = false
        authStore.lock()
        vaultStore.lock()
    }
}

