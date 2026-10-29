import SwiftUI

struct VaultSetupView: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""
    @State private var confirmation = ""
    @State private var hint = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    var required = false
    let onCreated: () -> Void

    private enum Field: Hashable {
        case passcode
        case confirmation
        case hint
    }

    private var trimmedHint: String {
        hint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        VaultAuthStore.isValidPasscode(passcode)
            && confirmation == passcode
            && (trimmedHint.isEmpty || !trimmedHint.localizedCaseInsensitiveContains(passcode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("设置口令", text: $passcode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .passcode)
                        .onSubmit { focusedField = .confirmation }
                        .accessibilityIdentifier("setup-passcode")
                    SecureField("再次输入", text: $confirmation)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .confirmation)
                        .onSubmit { focusedField = .hint }
                        .accessibilityIdentifier("setup-confirmation")
                    TextField("提示词（可选）", text: $hint)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .hint)
                        .onSubmit {
                            focusedField = nil
                            if canCreate { create() }
                        }

                    if !passcode.isEmpty && !VaultAuthStore.isValidPasscode(passcode) {
                        validationLabel("口令至少需要 6 位数字。")
                    } else if !confirmation.isEmpty && confirmation != passcode {
                        validationLabel("两次输入的口令不一致。")
                    } else if !passcode.isEmpty
                                && !trimmedHint.isEmpty
                                && trimmedHint.localizedCaseInsensitiveContains(passcode) {
                        validationLabel("提示词不能包含完整口令。")
                    }
                } header: {
                    Text("设置密码")
                } footer: {
                    Text("至少 6 位数字，建议使用 8 位以上。密码无法找回，请同时保管好后续创建的加密备份。")
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
                        .disabled(!canCreate)
                        .accessibilityIdentifier("setup-create")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
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
        .interactiveDismissDisabled(required || !passcode.isEmpty || !confirmation.isEmpty || !hint.isEmpty)
    }

    private func validationLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityIdentifier("setup-validation")
    }

    private func create() {
        do {
            try authStore.create(passcode: passcode, confirmation: confirmation, hint: trimmedHint)
            focusedField = nil
            dismiss()
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
