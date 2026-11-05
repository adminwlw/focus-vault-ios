import Foundation
import UserNotifications

@MainActor
final class FocusTimerStore: ObservableObject {
    private let stateKey = "focus-timer-state-v1"
    private let remindersKey = "focus-reminders-v1"
    private let nowProvider: () -> Date
    private var ticker: Timer?

    @Published private(set) var state = FocusTimerState()
    @Published private(set) var now: Date
    @Published private(set) var notificationsDenied = false
    @Published var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: remindersKey)
            if remindersEnabled {
                Task {
                    let granted = await requestNotificationPermission()
                    notificationsDenied = !granted
                    if !granted { remindersEnabled = false }
                }
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-timer"])
            }
        }
    }

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
        now = nowProvider()
        remindersEnabled = UserDefaults.standard.bool(forKey: remindersKey)
        load()
        refresh()
        updateTicker()
        Task { await refreshNotificationStatus() }
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
            ? "计时"
            : taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.plannedSeconds = seconds
        state.remainingWhenPaused = seconds
        state.phase = .idle
        save()
    }

    func start() {
        guard state.phase == .idle || state.phase == .finished else { return }
        let timestamp = nowProvider()
        now = timestamp
        let id = UUID()
        state.startedAt = timestamp
        state.sessionID = id
        state.remainingWhenPaused = state.plannedSeconds
        state.endDate = timestamp.addingTimeInterval(TimeInterval(state.plannedSeconds))
        state.phase = .running
        scheduleNotification()
        save()
        updateTicker()
    }

    func pause() {
        guard state.phase == .running else { return }
        now = nowProvider()
        state.remainingWhenPaused = remainingSeconds
        state.endDate = nil
        state.phase = .paused
        cancelNotification()
        save()
        updateTicker()
    }

    func resume() {
        guard state.phase == .paused else { return }
        let timestamp = nowProvider()
        now = timestamp
        state.endDate = timestamp.addingTimeInterval(TimeInterval(state.remainingWhenPaused))
        state.phase = .running
        scheduleNotification()
        save()
        updateTicker()
    }

    func endEarly() {
        guard state.phase == .running || state.phase == .paused else { return }
        now = nowProvider()
        reset()
    }

    func reset() {
        cancelNotification()
        now = nowProvider()
        state.phase = .idle
        state.endDate = nil
        state.sessionID = nil
        state.remainingWhenPaused = state.plannedSeconds
        state.startedAt = nil
        save()
        updateTicker()
    }

    func refresh() {
        now = nowProvider()
        if state.phase == .running, remainingSeconds == 0 {
            state.phase = .finished
            state.endDate = nil
            state.remainingWhenPaused = 0
            state.sessionID = nil
            save()
            updateTicker()
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
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }

    private func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    private func scheduleNotification() {
        guard remindersEnabled, let endDate = state.endDate else { return }
        let content = UNMutableNotificationContent()
        content.title = "计时完成"
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
