import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.openURL) private var openURL

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒") {
                    Toggle("计时结束提醒", isOn: $timerStore.remindersEnabled)
                    if timerStore.notificationsDenied {
                        Text("通知权限已关闭。计时和记录仍可正常使用，但后台结束时不会提醒。可在系统设置中重新开启。")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("打开系统设置") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                    }
                    Text("只在开启时请求通知权限。即使关闭提醒，计时记录仍会正常保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("版本", value: versionLabel)
                }
            }
            .navigationTitle("设置")
        }
    }
}

