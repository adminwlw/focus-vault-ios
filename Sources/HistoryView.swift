import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var timerStore: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    @State private var searchText = ""
    let onVaultUnlocked: () -> Void

    private var filteredSessions: [FocusSession] {
        guard !searchText.isEmpty else { return timerStore.sessions }
        return timerStore.sessions.filter { $0.taskName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if timerStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "还没有专注记录",
                        systemImage: "clock.badge.checkmark",
                        description: Text("完成一次专注后，记录会出现在这里。")
                    )
                    .listRowBackground(Color.clear)
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                } else {
                    summarySection
                    Section("记录") {
                        ForEach(filteredSessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
            .navigationTitle("记录")
            .searchable(text: $searchText, prompt: "搜索任务")
            .onSubmit(of: .search) {
                if authStore.hasVault, authStore.verify(searchText, quietly: true) {
                    searchText = ""
                    onVaultUnlocked()
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                summaryValue(title: "完成次数", value: "\(timerStore.sessions.filter { $0.outcome == .completed }.count)")
                Divider()
                summaryValue(
                    title: "专注时长",
                    value: "\(timerStore.sessions.reduce(0) { $0 + $1.focusedSeconds } / 60) 分钟"
                )
            }
            .padding(.vertical, 8)
        }
    }

    private func summaryValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.outcome == .completed ? "checkmark.circle.fill" : "stop.circle")
                .font(.title3)
                .foregroundStyle(session.outcome == .completed ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.taskName)
                    .font(.body.weight(.medium))
                Text(session.endedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.focusedSeconds / 60) 分钟")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

