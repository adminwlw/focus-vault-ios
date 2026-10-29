import SwiftUI

struct VaultSetupView: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""
    @State private var confirmation = ""
    @State private var hint = ""
    @State private var errorMessage: String?
    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("设置口令", text: $passcode)
                        .textContentType(.newPassword)
                    SecureField("再次输入", text: $confirmation)
                        .textContentType(.newPassword)
                    TextField("提示词（可选）", text: $hint)
                } header: {
                    Text("私人空间口令")
                } footer: {
                    Text("建议至少 8 位。提示词不能包含完整口令；客服无法找回口令。")
                }

                Section {
                    Label("媒体会加密保存在 App 内", systemImage: "lock.shield")
                    Label("卸载前需要创建加密备份", systemImage: "externaldrive")
                }
            }
            .navigationTitle("设置私人空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                        .disabled(passcode.isEmpty || confirmation.isEmpty)
                }
            }
            .alert("无法创建", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
        .interactiveDismissDisabled(!passcode.isEmpty || !confirmation.isEmpty)
    }

    private func create() {
        do {
            try authStore.create(passcode: passcode, confirmation: confirmation, hint: hint)
            dismiss()
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct VaultUnlockView: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""
    @State private var showHint = false
    let onUnlocked: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("输入口令", text: $passcode)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit { unlock() }
                    if let error = authStore.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if !authStore.hint.isEmpty {
                    Section {
                        Button(showHint ? authStore.hint : "显示口令提示") {
                            showHint = true
                        }
                    }
                }
            }
            .navigationTitle("私人空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("解锁") { unlock() }
                        .disabled(passcode.isEmpty)
                }
            }
        }
    }

    private func unlock() {
        guard authStore.verify(passcode) else {
            passcode = ""
            return
        }
        dismiss()
        onUnlocked()
    }
}
