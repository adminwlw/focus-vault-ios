import SwiftUI

struct StopwatchState: Codable {
    var accumulated: TimeInterval = 0
    var startedAt: Date?
    var laps: [TimeInterval] = []

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}

@MainActor
final class StopwatchStore: ObservableObject {
    @Published private(set) var state: StopwatchState
    private let defaults: UserDefaults
    private let now: () -> Date
    private let key = "stopwatch-state-v1"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(StopwatchState.self, from: $0) } ?? StopwatchState()
    }

    func start() {
        guard state.startedAt == nil else { return }
        state.startedAt = now()
        save()
    }

    func pause() {
        guard state.startedAt != nil else { return }
        state.accumulated = state.elapsed(at: now())
        state.startedAt = nil
        save()
    }

    func lap() {
        guard state.startedAt != nil, state.laps.count < 500 else { return }
        state.laps.append(state.elapsed(at: now()))
        save()
    }

    func reset() {
        guard state.startedAt == nil else { return }
        state = StopwatchState()
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(state), forKey: key)
    }
}

struct StopwatchView: View {
    @StateObject private var store = StopwatchStore()
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    TimelineView(.animation(minimumInterval: 0.05, paused: store.state.startedAt == nil)) { context in
                        Text(formatted(store.state.elapsed(at: context.date)))
                            .font(.system(size: 62, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.vertical, 48)
                            .accessibilityIdentifier("stopwatch-time")
                    }
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
                    layout {
                        Button(store.state.startedAt == nil ? "复位" : "计次") {
                            if store.state.startedAt == nil { store.reset() } else { store.lap() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.state.startedAt == nil && store.state.accumulated == 0)
                        .accessibilityIdentifier("stopwatch-lap-reset")
                        Button(store.state.startedAt == nil ? "开始" : "暂停") {
                            if store.state.startedAt == nil { store.start() } else { store.pause() }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("stopwatch-start-pause")
                    }
                    .controlSize(.large)
                    LazyVStack(spacing: 0) {
                        ForEach(store.state.laps.indices.reversed(), id: \.self) { index in
                            HStack {
                                Text("第 \(index + 1) 次")
                                Spacer()
                                Text(formatted(store.state.laps[index] - (index > 0 ? store.state.laps[index - 1] : 0)))
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 14)
                            Divider()
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("秒表")
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let hundredths = Int(max(0, seconds) * 100)
        return String(format: "%02d:%02d.%02d", hundredths / 6000, (hundredths / 100) % 60, hundredths % 100)
    }
}
