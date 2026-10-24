import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var scheduler: BreakScheduler!
    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != .current }) {
            NSApp.terminate(nil)
            return
        }

        NSApp.mainMenu = Self.makeMainMenu()

        let settings = Settings.shared
        let overlay = BreakOverlay()
        scheduler = BreakScheduler(settings: settings, stats: Stats.shared, overlay: overlay)
        overlay.scheduler = scheduler
        Notifier.shared.scheduler = scheduler
        Notifier.shared.setup()

        statusBar = StatusBarController(scheduler: scheduler) { [weak self] in self?.showSettings() }
        scheduler.onChange = { [weak self] in self?.statusBar.refresh() }

        // Rewrite the launch agent so it points at wherever the app lives now.
        if settings.launchAtLogin { LaunchAtLogin.set(true) }

        scheduler.start()
    }

    private func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(scheduler: scheduler) }
        settingsWindow?.present()
    }

    /// Menu bar apps have no menu bar, but text fields still need an Edit menu for ⌘C / ⌘V to work.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(withTitle: "Quit EyeBreak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }
}
