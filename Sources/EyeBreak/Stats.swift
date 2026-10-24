import Foundation

/// Break history. A streak survives one skip; a second skip in a row resets it.
final class Stats: ObservableObject {
    static let shared = Stats()

    private let defaults = UserDefaults.standard

    @Published private(set) var breaksTaken: Int
    @Published private(set) var streak: Int
    @Published private(set) var bestStreak: Int
    @Published private(set) var skips: Int
    @Published private(set) var consecutiveSkips: Int

    /// True when skipping the current break would reset the streak.
    var nextSkipResetsStreak: Bool { streak > 0 && consecutiveSkips >= 1 }

    private init() {
        breaksTaken = defaults.integer(forKey: "stats.breaksTaken")
        streak = defaults.integer(forKey: "stats.streak")
        bestStreak = defaults.integer(forKey: "stats.bestStreak")
        skips = defaults.integer(forKey: "stats.skips")
        consecutiveSkips = defaults.integer(forKey: "stats.consecutiveSkips")
    }

    func recordCompleted() {
        breaksTaken += 1
        streak += 1
        bestStreak = max(bestStreak, streak)
        consecutiveSkips = 0
        save()
    }

    func recordSkip() {
        skips += 1
        consecutiveSkips += 1
        if consecutiveSkips >= 2 { streak = 0 }
        save()
    }

    func reset() {
        breaksTaken = 0
        streak = 0
        bestStreak = 0
        skips = 0
        consecutiveSkips = 0
        save()
    }

    private func save() {
        defaults.set(breaksTaken, forKey: "stats.breaksTaken")
        defaults.set(streak, forKey: "stats.streak")
        defaults.set(bestStreak, forKey: "stats.bestStreak")
        defaults.set(skips, forKey: "stats.skips")
        defaults.set(consecutiveSkips, forKey: "stats.consecutiveSkips")
    }
}
