import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var store: FocusTimerStore
    @State private var taskName = "专注任务"
    @State private var selectedMinutes = 25
    @State private var showDurationPicker = false

    private var isEditable: Bool {
        store.state.phase == .idle || store.state.phase == .finished
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    timerDial
                    taskEditor
                    primaryControls
                    presetControls
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("专注")
            .sheet(isPresented: $showDurationPicker) {
                NavigationStack {
                    Form {
                        Picker("专注时长", selection: $selectedMinutes) {
                            ForEach([5, 10, 15, 20, 25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes) 分钟").tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .navigationTitle("选择时长")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                applyConfiguration()
                                showDurationPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                taskName = store.state.taskName
                selectedMinutes = max(1, store.state.plannedSeconds / 60)
            }
        }
    }

    private var timerDial: some View {
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
                    .font(.system(size: 58, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(phaseLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 270, height: 270)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余时间 \(formattedTime(store.remainingSeconds))，\(phaseLabel)")
    }

    private var taskEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前任务")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("专注任务", text: $taskName)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .disabled(!isEditable)
                .submitLabel(.done)
                .onSubmit { applyConfiguration() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var primaryControls: some View {
        switch store.state.phase {
        case .idle, .finished:
            Button {
                applyConfiguration()
                store.start()
            } label: {
                Label(store.state.phase == .finished ? "再次开始" : "开始专注", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

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
                    Text("结束")
                        .frame(maxWidth: .infinity)
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
                    Text("结束")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var presetControls: some View {
        HStack(spacing: 10) {
            presetButton(title: "专注", minutes: 25)
            presetButton(title: "短休息", minutes: 5)
            Button {
                showDurationPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("自定义")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.bordered)
            .disabled(!isEditable)
        }
    }

    private func presetButton(title: String, minutes: Int) -> some View {
        Button {
            selectedMinutes = minutes
            applyConfiguration()
        } label: {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.headline.monospacedDigit())
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.bordered)
        .disabled(!isEditable)
    }

    private var phaseLabel: String {
        switch store.state.phase {
        case .idle: "准备开始"
        case .running: "正在专注"
        case .paused: "已暂停"
        case .finished: "本次已完成"
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func applyConfiguration() {
        store.configure(taskName: taskName, seconds: selectedMinutes * 60)
    }
}

