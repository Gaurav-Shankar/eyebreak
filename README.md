# EyeBreak

A lightweight macOS menu bar app that reminds you to rest your eyes with the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.

## Build

```sh
./build.sh            # builds build/EyeBreak.app
./build.sh --install  # also copies it to /Applications and relaunches it
```

Requires macOS 12+ and the Xcode Command Line Tools. It compiles with `swiftc` directly (no Xcode or SwiftPM needed) into a universal app that runs natively on Apple Silicon and Intel. For a quicker single-architecture build: `ARCHS=arm64 ./build.sh`.

## Layout

| File | What it does |
|---|---|
| `BreakScheduler.swift` | Work/break state machine, snooze, pausing when the Mac sleeps or locks |
| `BreakOverlay.swift`, `BreakView.swift` | Full-screen break on every display |
| `Notifier.swift` | Heads-up and notification-only breaks |
| `StatusBarController.swift` | Menu bar icon, countdown and menu |
| `SettingsView.swift` | Settings window |
| `Settings.swift`, `Stats.swift` | Preferences and streaks (UserDefaults) |
| `LaunchAtLogin.swift` | Login item via `~/Library/LaunchAgents` |

## License

MIT — see [LICENSE](LICENSE).
