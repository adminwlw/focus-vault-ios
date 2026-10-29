import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒") {
                    Toggle("计时结束提醒", isOn: $timerStore.remindersEnabled)
                    if timerStore.notificationsDenied {
                        Text("通知权限已关闭。计时和记录仍可正常使用，但后台结束时不会提醒。可在系统设置中重新开启。")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("只在开启时请求通知权限。即使关闭提醒，计时记录仍会正常保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (1)")
                }
            }
            .navigationTitle("设置")
        }
    }
}

