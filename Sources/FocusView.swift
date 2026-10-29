import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var store: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    @State private var taskName = "计时"
    @State private var durationInput = "25"
    @State private var lastValidMinutes = 25
    let onVaultUnlocked: () -> Void

    private var isEditable: Bool {
        store.state.phase == .idle || store.state.phase == .finished
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    timerDial
                    manualTimerEditor
                    primaryControls
                    quickDurations
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("计时器")
            .onAppear {
                taskName = store.state.taskName == "专注任务" ? "计时" : store.state.taskName
                lastValidMinutes = max(1, store.state.plannedSeconds / 60)
                durationInput = String(lastValidMinutes)
            }
        }
    }

    private var timerDial: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, 270)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.002, store.progress))
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: store.progress)

                VStack(spacing: 8) {
                    Text(formattedTime(store.remainingSeconds))
                        .font(.system(size: 56, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                    Text(phaseLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(22)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 270)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余时间 \(formattedTime(store.remainingSeconds))，\(phaseLabel)")
    }

    private var manualTimerEditor: some View {
        VStack(spacing: 14) {
            HStack {
                Text("计时时长")
                    .font(.body.weight(.medium))
                Spacer()
                TextField("分钟", text: $durationInput)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .frame(minWidth: 92, maxWidth: 180)
                    .disabled(!isEditable)
                    .onSubmit { startOrUnlock() }
                    .accessibilityIdentifier("timer-duration")
                Text("分钟")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("名称")
                    .font(.body.weight(.medium))
                Spacer()
                TextField("计时", text: $taskName)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .frame(minWidth: 120, maxWidth: 260)
                    .disabled(!isEditable)
                    .accessibilityIdentifier("timer-name")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var primaryControls: some View {
        switch store.state.phase {
        case .idle, .finished:
            Button(action: startOrUnlock) {
                Label(store.state.phase == .finished ? "再次计时" : "开始计时", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("timer-start")

        case .running:
            HStack(spacing: 12) {
                Button {
                    store.pause()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    store.endEarly()
                } label: {
                    Text("结束").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

        case .paused:
            HStack(spacing: 12) {
                Button {
                    store.resume()
                } label: {
                    Label("继续", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    store.endEarly()
                } label: {
                    Text("结束").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var quickDurations: some View {
        HStack(spacing: 10) {
            ForEach([5, 10, 30], id: \.self) { minutes in
                Button {
                    lastValidMinutes = minutes
                    durationInput = String(minutes)
                } label: {
                    Text("\(minutes) 分钟")
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .buttonStyle(.bordered)
                .disabled(!isEditable)
            }
        }
    }

    private var phaseLabel: String {
        switch store.state.phase {
        case .idle: return "准备开始"
        case .running: return "计时中"
        case .paused: return "已暂停"
        case .finished: return "本次已完成"
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, remainder) }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private func startOrUnlock() {
        let input = durationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if authStore.hasVault, authStore.verify(input, quietly: true) {
            durationInput = String(lastValidMinutes)
            onVaultUnlocked()
            return
        }

        if let minutes = Int(input), (1...1_440).contains(minutes) {
            lastValidMinutes = minutes
        }
        durationInput = String(lastValidMinutes)
        store.configure(taskName: taskName, seconds: lastValidMinutes * 60)
        store.start()
    }
}
