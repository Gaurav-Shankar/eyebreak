import Foundation

enum BreakStyle: String, CaseIterable, Identifiable {
    case fullScreen, notification
    var id: String { rawValue }
    var label: String { self == .fullScreen ? "Full-screen break" : "Notification only" }
}

enum SkipMode: String, CaseIterable, Identifiable {
    case anytime, afterDelay, never
    static let delay: TimeInterval = 5

    var id: String { rawValue }
    var label: String {
        switch self {
        case .anytime: return "Anytime"
        case .afterDelay: return "After \(Int(SkipMode.delay)) seconds"
        case .never: return "Never"
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case ocean, forest, sunset, dusk, graphite
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// User preferences, persisted to UserDefaults on every change.
final class Settings: ObservableObject {
    static let shared = Settings()
    static let breakLengthOptions = [10, 20, 30, 45, 60, 120, 300, 600, 900]
    static let headsUpOptions = [0, 5, 20]

    private let defaults = UserDefaults.standard

    private enum Key {
        static let workMinutes = "workMinutes"
        static let breakSeconds = "breakSeconds"
        static let breakStyle = "breakStyle"
        static let headsUpSeconds = "headsUpSeconds"
        static let skipMode = "skipMode"
        static let message = "message"
        static let theme = "theme"
        static let chime = "chime"
        static let chimeAtStart = "chimeAtStart"
        static let chimeAtEnd = "chimeAtEnd"
        static let showCountdown = "showCountdownInMenuBar"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var workMinutes: Int { didSet { defaults.set(workMinutes, forKey: Key.workMinutes) } }
    @Published var breakSeconds: Int { didSet { defaults.set(breakSeconds, forKey: Key.breakSeconds) } }
    @Published var breakStyle: BreakStyle { didSet { defaults.set(breakStyle.rawValue, forKey: Key.breakStyle) } }
    @Published var headsUpSeconds: Int { didSet { defaults.set(headsUpSeconds, forKey: Key.headsUpSeconds) } }
    @Published var skipMode: SkipMode { didSet { defaults.set(skipMode.rawValue, forKey: Key.skipMode) } }
    @Published var message: String { didSet { defaults.set(message, forKey: Key.message) } }
    @Published var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: Key.theme) } }
    /// System sound name; empty string means no chime.
    @Published var chime: String { didSet { defaults.set(chime, forKey: Key.chime) } }
    @Published var chimeAtStart: Bool { didSet { defaults.set(chimeAtStart, forKey: Key.chimeAtStart) } }
    @Published var chimeAtEnd: Bool { didSet { defaults.set(chimeAtEnd, forKey: Key.chimeAtEnd) } }
    @Published var showCountdownInMenuBar: Bool { didSet { defaults.set(showCountdownInMenuBar, forKey: Key.showCountdown) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }

    var workInterval: TimeInterval { TimeInterval(min(max(workMinutes, 1), 240) * 60) }
    var breakDuration: TimeInterval { TimeInterval(max(breakSeconds, 5)) }

    private init() {
        defaults.register(defaults: [
            Key.workMinutes: 20,
            Key.breakSeconds: 20,
            Key.breakStyle: BreakStyle.fullScreen.rawValue,
            Key.headsUpSeconds: 5,
            Key.skipMode: SkipMode.anytime.rawValue,
            Key.message: "Look at something 20 feet away",
            Key.theme: Theme.ocean.rawValue,
            Key.chime: "Glass",
            Key.chimeAtStart: false,
            Key.chimeAtEnd: true,
            Key.showCountdown: true,
            Key.launchAtLogin: false,
        ])
        workMinutes = defaults.integer(forKey: Key.workMinutes)
        breakSeconds = defaults.integer(forKey: Key.breakSeconds)
        breakStyle = BreakStyle(rawValue: defaults.string(forKey: Key.breakStyle) ?? "") ?? .fullScreen
        headsUpSeconds = defaults.integer(forKey: Key.headsUpSeconds)
        skipMode = SkipMode(rawValue: defaults.string(forKey: Key.skipMode) ?? "") ?? .anytime
        message = defaults.string(forKey: Key.message) ?? ""
        theme = Theme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .ocean
        chime = defaults.string(forKey: Key.chime) ?? ""
        chimeAtStart = defaults.bool(forKey: Key.chimeAtStart)
        chimeAtEnd = defaults.bool(forKey: Key.chimeAtEnd)
        showCountdownInMenuBar = defaults.bool(forKey: Key.showCountdown)
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
    }
}
