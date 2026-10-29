import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    let openVault: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒") {
                    Toggle("专注结束提醒", isOn: $timerStore.remindersEnabled)
                    Text("只在开启时请求通知权限。即使关闭提醒，计时记录仍会正常保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("私人空间") {
                    Button(action: openVault) {
                        Label(
                            authStore.hasVault ? "打开私人空间" : "设置私人空间",
                            systemImage: authStore.hasVault ? "lock.open" : "lock"
                        )
                    }
                    if authStore.hasVault, !authStore.hint.isEmpty {
                        LabeledContent("口令提示", value: authStore.hint)
                    }
                    Text("私人媒体保存在 App 的受保护目录并加密。卸载 App 前请先创建加密备份。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (1)")
                    NavigationLink("隐私与安全说明") {
                        SecurityNotesView()
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

private struct SecurityNotesView: View {
    var body: some View {
        List {
            Section("本机存储") {
                Text("私人照片和视频不会上传到开发者服务器。系统设备备份是否包含 App 数据取决于你的 iPhone 备份设置。")
            }
            Section("威胁边界") {
                Text("本功能用于防止借出已解锁手机时的随手查看，无法抵御已知口令者、越狱设备或系统级取证。")
            }
            Section("数据丢失") {
                Text("忘记口令、备份密码，或在没有备份时卸载 App，可能导致私人内容永久丢失。")
            }
        }
        .navigationTitle("隐私与安全")
        .navigationBarTitleDisplayMode(.inline)
    }
}

