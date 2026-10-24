import AppKit

/// The menu bar icon, countdown and menu.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scheduler: BreakScheduler
    private let settings: Settings
    private let stats: Stats
    private let openSettings: () -> Void
    private let headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var currentSymbol = ""

    init(scheduler: BreakScheduler, openSettings: @escaping () -> Void) {
        self.scheduler = scheduler
        self.settings = scheduler.settings
        self.stats = scheduler.stats
        self.openSettings = openSettings
        super.init()
        item.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        headerItem.isEnabled = false
        refresh()
    }

    func refresh() {
        guard let button = item.button else { return }
        let symbol: String
        switch scheduler.state {
        case .working: symbol = "eye"
        case .onBreak: symbol = "eye.fill"
        case .snoozed, .paused: symbol = "eye.slash"
        }
        if symbol != currentSymbol {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "EyeBreak")
            image?.isTemplate = true
            button.image = image
            currentSymbol = symbol
        }
        let title = settings.showCountdownInMenuBar ? shortCountdown() : ""
        button.title = title.isEmpty ? "" : " " + title
        headerItem.title = statusLine()
    }

    private func shortCountdown() -> String {
        switch scheduler.state {
        case .working:
            let remaining = scheduler.timeUntilBreak
            return remaining >= 60 ? "\(Int((remaining / 60).rounded(.up)))m" : "\(Int(remaining.rounded(.up)))s"
        case .onBreak, .snoozed, .paused:
            return ""
        }
    }

    private func statusLine() -> String {
        switch scheduler.state {
        case .working:
            return "Next break in \(BreakView.clock(scheduler.timeUntilBreak))"
        case .onBreak:
            let left = max(0, scheduler.breakEndsAt?.timeIntervalSinceNow ?? 0)
            return "On a break — \(BreakView.clock(left)) left"
        case .snoozed:
            guard let until = scheduler.snoozeUntil else { return "Snoozed" }
            let formatter = DateFormatter()
            formatter.dateStyle = Calendar.current.isDateInToday(until) ? .none : .short
            formatter.timeStyle = .short
            return "Snoozed until \(formatter.string(from: until))"
        case .paused:
            return "Paused while you're away"
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        refresh()
        menu.addItem(headerItem)
        if stats.streak > 0 {
            menu.addItem(disabled("Streak: \(stats.streak) break\(stats.streak == 1 ? "" : "s") in a row"))
        }
        menu.addItem(.separator())

        if scheduler.state == .onBreak {
            if scheduler.canSkip() { menu.addItem(action("Skip Break", #selector(skipBreak))) }
        } else {
            menu.addItem(action("Take a Break Now", #selector(takeBreak)))
        }
        menu.addItem(action("Just Took a Break", #selector(justTookBreak)))

        if scheduler.state == .snoozed {
            menu.addItem(action("Resume Breaks", #selector(resume)))
        } else {
            let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for (title, minutes) in [("30 Minutes", 30), ("1 Hour", 60), ("2 Hours", 120), ("4 Hours", 240), ("Until Tomorrow", -1)] {
                let snooze = action(title, #selector(snooze(_:)))
                snooze.tag = minutes
                submenu.addItem(snooze)
            }
            snoozeItem.submenu = submenu
            menu.addItem(snoozeItem)
        }

        menu.addItem(.separator())
        menu.addItem(action("Settings…", #selector(showSettings), key: ","))
        menu.addItem(action("Quit EyeBreak", #selector(quit), key: "q"))
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    @objc private func takeBreak() { scheduler.takeBreakNow() }
    @objc private func skipBreak() { scheduler.skip() }
    @objc private func justTookBreak() { scheduler.justTookBreak() }
    @objc private func resume() { scheduler.resume() }
    @objc private func showSettings() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func snooze(_ sender: NSMenuItem) {
        if sender.tag < 0 {
            scheduler.snoozeUntilTomorrow()
        } else {
            scheduler.snooze(for: TimeInterval(sender.tag * 60))
        }
    }
}
