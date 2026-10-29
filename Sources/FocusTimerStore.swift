import Foundation
import UserNotifications

@MainActor
final class FocusTimerStore: ObservableObject {
    private let stateKey = "focus-timer-state-v1"
    private let sessionsKey = "focus-sessions-v1"
    private let remindersKey = "focus-reminders-v1"
    private var ticker: Timer?
    private var sessionStartedAt: Date?

    @Published private(set) var state = FocusTimerState()
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var now = Date()
    @Published var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: remindersKey)
            if remindersEnabled {
                Task { await requestNotificationPermission() }
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-timer"])
            }
        }
    }

    init() {
        remindersEnabled = UserDefaults.standard.bool(forKey: remindersKey)
        load()
        refresh()
        updateTicker()
    }

    var remainingSeconds: Int {
        switch state.phase {
        case .running:
            guard let endDate = state.endDate else { return 0 }
            return max(0, Int(ceil(endDate.timeIntervalSince(now))))
        case .paused, .idle:
            return max(0, state.remainingWhenPaused)
        case .finished:
            return 0
        }
    }

    var progress: Double {
        guard state.plannedSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(state.plannedSeconds)
    }

    func configure(taskName: String, seconds: Int) {
        guard state.phase == .idle || state.phase == .finished else { return }
        state.taskName = taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "专注任务"
            : taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.plannedSeconds = seconds
        state.remainingWhenPaused = seconds
        state.phase = .idle
        save()
    }

    func start() {
        guard state.phase == .idle || state.phase == .finished else { return }
        let id = UUID()
        sessionStartedAt = Date()
        state.sessionID = id
        state.remainingWhenPaused = state.plannedSeconds
        state.endDate = Date().addingTimeInterval(TimeInterval(state.plannedSeconds))
        state.phase = .running
        scheduleNotification()
        save()
        updateTicker()
    }

    func pause() {
        guard state.phase == .running else { return }
        state.remainingWhenPaused = remainingSeconds
        state.endDate = nil
        state.phase = .paused
        cancelNotification()
        save()
        updateTicker()
    }

    func resume() {
        guard state.phase == .paused else { return }
        state.endDate = Date().addingTimeInterval(TimeInterval(state.remainingWhenPaused))
        state.phase = .running
        scheduleNotification()
        save()
        updateTicker()
    }

    func endEarly() {
        guard state.phase == .running || state.phase == .paused else { return }
        let focused = max(0, state.plannedSeconds - remainingSeconds)
        appendSession(outcome: .endedEarly, focusedSeconds: focused)
        reset()
    }

    func reset() {
        cancelNotification()
        state.phase = .idle
        state.endDate = nil
        state.sessionID = nil
        state.remainingWhenPaused = state.plannedSeconds
        sessionStartedAt = nil
        save()
        updateTicker()
    }

    func refresh() {
        now = Date()
        if state.phase == .running, remainingSeconds == 0 {
            appendSession(outcome: .completed, focusedSeconds: state.plannedSeconds)
            state.phase = .finished
            state.endDate = nil
            state.remainingWhenPaused = 0
            state.sessionID = nil
            sessionStartedAt = nil
            save()
            updateTicker()
        }
    }

    private func appendSession(outcome: FocusSession.Outcome, focusedSeconds: Int) {
        let endedAt = Date()
        let startedAt = sessionStartedAt ?? endedAt.addingTimeInterval(-TimeInterval(focusedSeconds))
        let session = FocusSession(
            id: state.sessionID ?? UUID(),
            taskName: state.taskName,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedSeconds: state.plannedSeconds,
            focusedSeconds: focusedSeconds,
            outcome: outcome
        )
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.insert(session, at: 0)
        }
    }

    private func updateTicker() {
        ticker?.invalidate()
        ticker = nil
        guard state.phase == .running else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode(FocusTimerState.self, from: data) {
            state = decoded
        }
        if let data = defaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = decoded
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(state), forKey: stateKey)
        defaults.set(try? JSONEncoder().encode(sessions), forKey: sessionsKey)
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private func scheduleNotification() {
        guard remindersEnabled, let endDate = state.endDate else { return }
        let content = UNMutableNotificationContent()
        content.title = "专注完成"
        content.body = "\(state.taskName) 已结束。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: "focus-timer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-timer"])
    }
}
