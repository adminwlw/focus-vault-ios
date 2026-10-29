import SwiftUI

struct VaultSetupView: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    var required = false
    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("设置口令", text: $passcode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("setup-passcode")
                    SecureField("再次输入", text: $confirmation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("setup-confirmation")
                } header: {
                    Text("设置密码")
                } footer: {
                    Text("建议至少 8 位。密码无法由客服找回，请同时保管好后续创建的加密备份。")
                }

                Section {
                    Label("媒体会加密保存在 App 内", systemImage: "lock.shield")
                    Label("导入是复制，系统照片原件不会自动删除", systemImage: "photo.on.rectangle")
                    Label("卸载前需要创建加密备份", systemImage: "externaldrive")
                    Label("日常在计时时长输入框输入完整密码并开始", systemImage: "timer")
                }
            }
            .navigationTitle("设置私人空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !required {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                        .disabled(passcode.isEmpty || confirmation.isEmpty)
                        .accessibilityIdentifier("setup-create")
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
        .interactiveDismissDisabled(required || !passcode.isEmpty || !confirmation.isEmpty)
    }

    private func create() {
        do {
            try authStore.create(passcode: passcode, confirmation: confirmation, hint: "")
            dismiss()
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
