import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var store: FocusTimerStore
    @EnvironmentObject private var authStore: VaultAuthStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var taskName = "计时"
    @State private var durationInput = "25"
    @State private var lastValidMinutes = 25
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .largeTitle) private var timerTextSize: CGFloat = 56
    let onVaultUnlocked: () -> Void

    private enum Field: Hashable {
        case duration
        case taskName
    }

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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("计时器")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .duration {
                        Button("确认") { startOrUnlock() }
                            .accessibilityIdentifier("timer-confirm-input")
                    }
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .onAppear {
                taskName = store.state.taskName == "专注任务" ? "计时" : store.state.taskName
                lastValidMinutes = max(1, store.state.plannedSeconds / 60)
                durationInput = String(lastValidMinutes)
            }
            .onChange(of: focusedField) { field in
                if field == .duration,
                   durationInput == String(lastValidMinutes) {
                    durationInput = ""
                } else if field != .duration,
                          durationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    durationInput = String(lastValidMinutes)
                }
            }
        }
    }

    private var timerDial: some View {
        GeometryReader { proxy in
            let maximumSize: CGFloat = dynamicTypeSize.isAccessibilitySize ? 236 : 270
            let size = min(proxy.size.width, maximumSize)
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: store.progress)

                VStack(spacing: 8) {
                    Text(formattedTime(store.remainingSeconds))
                        .font(.system(size: min(timerTextSize, 72), weight: .thin, design: .rounded))
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
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 236 : 270)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余时间 \(formattedTime(store.remainingSeconds))，\(phaseLabel)")
    }

    private var manualTimerEditor: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    timerFieldLabel("计时时长")
                    Spacer()
                    durationField
                }
                VStack(alignment: .leading, spacing: 8) {
                    timerFieldLabel("计时时长")
                    durationField
                }
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack {
                    timerFieldLabel("名称")
                    Spacer()
                    taskNameField
                }
                VStack(alignment: .leading, spacing: 8) {
                    timerFieldLabel("名称")
                    taskNameField
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var durationField: some View {
        HStack(spacing: 8) {
            TextField("分钟", text: $durationInput)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focusedField, equals: .duration)
                .frame(minWidth: 92, maxWidth: 180)
                .onChange(of: durationInput) { newValue in
                    let digits = newValue.filter { $0 >= "0" && $0 <= "9" }
                    if digits != newValue { durationInput = digits }
                }
                .onSubmit { startOrUnlock() }
                .accessibilityIdentifier("timer-duration")
            Text("分钟")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 220, alignment: .trailing)
    }

    private var taskNameField: some View {
        TextField("计时", text: $taskName)
            .multilineTextAlignment(.trailing)
            .submitLabel(.done)
            .focused($focusedField, equals: .taskName)
            .frame(minWidth: 120, maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
            .disabled(!isEditable)
            .accessibilityIdentifier("timer-name")
    }

    private func timerFieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.medium))
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
            adaptiveButtonLayout {
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
            adaptiveButtonLayout {
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
        adaptiveButtonLayout {
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

    private var adaptiveButtonLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .center, spacing: 10))
        }
        return AnyLayout(HStackLayout(alignment: .center, spacing: 10))
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
        focusedField = nil
        if VaultAuthStore.isValidPasscode(input), authStore.hasVault, authStore.verify(input, quietly: true) {
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
