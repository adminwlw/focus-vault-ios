import SwiftUI

struct HistoryView: View {
    private struct DailyGroup: Identifiable {
        let day: Date
        let sessions: [FocusSession]
        var id: Date { day }
    }

    @EnvironmentObject private var timerStore: FocusTimerStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""

    private var filteredSessions: [FocusSession] {
        guard !searchText.isEmpty else { return timerStore.sessions }
        return timerStore.sessions.filter { $0.taskName.localizedCaseInsensitiveContains(searchText) }
    }

    private var dailyGroups: [DailyGroup] {
        let grouped = Dictionary(grouping: filteredSessions) {
            Calendar.current.startOfDay(for: $0.endedAt)
        }
        return grouped
            .map { DailyGroup(day: $0.key, sessions: $0.value.sorted { $0.endedAt > $1.endedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                if timerStore.sessions.isEmpty {
                    EmptyStateView(
                        "还没有计时记录",
                        systemImage: "clock.badge.checkmark",
                        description: "完成一次计时后，记录会出现在这里。"
                    )
                    .listRowBackground(Color.clear)
                } else if filteredSessions.isEmpty {
                    EmptyStateView(
                        "没有找到记录",
                        systemImage: "magnifyingglass",
                        description: "没有与“\(searchText)”匹配的计时记录。"
                    )
                        .listRowBackground(Color.clear)
                } else {
                    summarySection
                    ForEach(dailyGroups) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        } header: {
                            dailyHeader(day: group.day, sessions: group.sessions)
                        }
                    }
                }
            }
            .navigationTitle("记录")
            .searchable(text: $searchText, prompt: "搜索任务")
        }
    }

    private func dailyHeader(day: Date, sessions: [FocusSession]) -> some View {
        let completed = sessions.filter { $0.outcome == .completed }.count
        let minutes = sessions.reduce(0) { $0 + $1.focusedSeconds } / 60
        return HStack {
            Text(day, format: .dateTime.year().month().day())
            Spacer()
            Text("完成 \(completed) 次 · \(minutes) 分钟")
        }
    }

    private var summarySection: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack {
                    completedSummary
                    Divider()
                    durationSummary
                }
                VStack(alignment: .leading, spacing: 16) {
                    completedSummary
                    Divider()
                    durationSummary
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var completedSummary: some View {
        summaryValue(
            title: "完成次数",
            value: "\(timerStore.sessions.filter { $0.outcome == .completed }.count)"
        )
    }

    private var durationSummary: some View {
        summaryValue(
            title: "计时时长",
            value: "\(timerStore.sessions.reduce(0) { $0 + $1.focusedSeconds } / 60) 分钟"
        )
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                sessionIdentity(session)
                Spacer(minLength: 8)
                durationLabel(session)
            }
            VStack(alignment: .leading, spacing: 8) {
                sessionIdentity(session)
                durationLabel(session)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sessionIdentity(_ session: FocusSession) -> some View {
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
        }
        .layoutPriority(1)
    }

    private func durationLabel(_ session: FocusSession) -> some View {
        Text("\(session.focusedSeconds / 60) 分钟")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
    }
}

