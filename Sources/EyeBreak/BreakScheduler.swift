import AppKit
import Combine

/// Owns the work/break cycle. Ticks once a second and drives the overlay, notifications and menu bar.
final class BreakScheduler: ObservableObject {
    enum State: Equatable {
        case working, onBreak, snoozed, paused
    }

    @Published private(set) var state: State = .working
    @Published private(set) var nextBreakAt = Date()
    @Published private(set) var breakStartedAt: Date?
    @Published private(set) var breakEndsAt: Date?
    @Published private(set) var snoozeUntil: Date?

    /// Called after every tick and state change.
    var onChange: (() -> Void)?

    let settings: Settings
    let stats: Stats
    private let overlay: BreakOverlay
    private var timer: Timer?
    private var headsUpSent = false
    private var cancellables = Set<AnyCancellable>()

    // Pausing while the Mac sleeps, the screen is locked, or the screensaver runs.
    private var pauseReasons = Set<String>()
    private var pausedAt: Date?
    private var pausedRemaining: TimeInterval = 0

    var breakDuration: TimeInterval { settings.breakDuration }
    var timeUntilBreak: TimeInterval { max(0, nextBreakAt.timeIntervalSinceNow) }

    init(settings: Settings, stats: Stats, overlay: BreakOverlay) {
        self.settings = settings
        self.stats = stats
        self.overlay = overlay
    }

    func start() {
        resetWorkTimer()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observeSystemEvents()

        // @Published fires before the new value is stored, so read it on the next run loop pass.
        settings.$workMinutes.dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    if self?.state == .working { self?.resetWorkTimer() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func takeBreakNow() {
        if state == .paused { pauseReasons.removeAll() }
        startBreak()
    }

    func skip() {
        finishBreak(completed: false)
    }

    /// Skips the upcoming break from the heads-up notification.
    func skipUpcoming() {
        guard state == .working else { return }
        stats.recordSkip()
        resetWorkTimer()
    }

    func justTookBreak() {
        if state == .onBreak {
            finishBreak(completed: true)
        } else {
            pauseReasons.removeAll()
            snoozeUntil = nil
            state = .working
            resetWorkTimer()
        }
    }

    func snooze(for interval: TimeInterval) {
        snooze(until: Date().addingTimeInterval(interval))
    }

    func snoozeUntilTomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        snooze(until: tomorrow)
    }

    func resume() {
        pauseReasons.removeAll()
        snoozeUntil = nil
        state = .working
        resetWorkTimer()
    }

    func canSkip(at now: Date = Date()) -> Bool {
        switch settings.skipMode {
        case .anytime:
            return true
        case .never:
            return false
        case .afterDelay:
            guard let started = breakStartedAt else { return true }
            return now.timeIntervalSince(started) >= SkipMode.delay
        }
    }

    // MARK: - Cycle

    private func tick() {
        let now = Date()
        switch state {
        case .working:
            let remaining = nextBreakAt.timeIntervalSince(now)
            if settings.headsUpSeconds > 0, !headsUpSent, remaining > 0, remaining <= Double(settings.headsUpSeconds) {
                headsUpSent = true
                Notifier.shared.headsUp(in: Int(remaining.rounded()))
            }
            if remaining <= 0 { startBreak() }
        case .onBreak:
            if let end = breakEndsAt, now >= end { finishBreak(completed: true) }
        case .snoozed:
            if let until = snoozeUntil, now >= until { resume() }
        case .paused:
            break
        }
        onChange?()
    }

    private func startBreak() {
        guard state != .onBreak else { return }
        let now = Date()
        state = .onBreak
        snoozeUntil = nil
        breakStartedAt = now
        breakEndsAt = now.addingTimeInterval(breakDuration)
        Notifier.shared.clearHeadsUp()
        if settings.chimeAtStart { Chime.play(settings.chime) }
        switch settings.breakStyle {
        case .fullScreen: overlay.show()
        case .notification: Notifier.shared.breakStarted()
        }
        onChange?()
    }

    private func finishBreak(completed: Bool) {
        guard state == .onBreak else { return }
        overlay.hide()
        if completed {
            stats.recordCompleted()
            if settings.chimeAtEnd { Chime.play(settings.chime) }
        } else {
            stats.recordSkip()
        }
        breakStartedAt = nil
        breakEndsAt = nil
        state = .working
        resetWorkTimer()
    }

    private func snooze(until date: Date) {
        if state == .onBreak {
            overlay.hide()
            breakStartedAt = nil
            breakEndsAt = nil
        }
        pauseReasons.removeAll()
        Notifier.shared.clearHeadsUp()
        snoozeUntil = date
        state = .snoozed
        onChange?()
    }

    private func resetWorkTimer() {
        nextBreakAt = Date().addingTimeInterval(settings.workInterval)
        headsUpSent = false
        onChange?()
    }

    // MARK: - Away detection

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(NSNotification.Name, NSNotification.Name, String)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, "sleep"),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, "display"),
        ]
        for (begin, end, reason) in pairs {
            workspace.addObserver(forName: begin, object: nil, queue: .main) { [weak self] _ in self?.addPause(reason) }
            workspace.addObserver(forName: end, object: nil, queue: .main) { [weak self] _ in self?.removePause(reason) }
        }

        let distributed = DistributedNotificationCenter.default()
        let distributedPairs = [
            ("com.apple.screenIsLocked", "com.apple.screenIsUnlocked", "lock"),
            ("com.apple.screensaver.didstart", "com.apple.screensaver.didstop", "screensaver"),
        ]
        for (begin, end, reason) in distributedPairs {
            distributed.addObserver(forName: .init(begin), object: nil, queue: .main) { [weak self] _ in self?.addPause(reason) }
            distributed.addObserver(forName: .init(end), object: nil, queue: .main) { [weak self] _ in self?.removePause(reason) }
        }
    }

    private func addPause(_ reason: String) {
        pauseReasons.insert(reason)
        // Being away counts as resting your eyes.
        if state == .onBreak { finishBreak(completed: true) }
        guard state == .working else { return }
        pausedRemaining = timeUntilBreak
        pausedAt = Date()
        state = .paused
        onChange?()
    }

    private func removePause(_ reason: String) {
        pauseReasons.remove(reason)
        guard pauseReasons.isEmpty, state == .paused else { return }
        let away = Date().timeIntervalSince(pausedAt ?? Date())
        state = .working
        if away >= breakDuration {
            resetWorkTimer()
        } else {
            nextBreakAt = Date().addingTimeInterval(pausedRemaining)
            headsUpSent = false
            onChange?()
        }
    }
}
