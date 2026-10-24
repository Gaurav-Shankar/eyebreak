import AppKit
import SwiftUI

/// Borderless windows can't take keyboard focus by default; we need it for the spacebar.
private final class BreakWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows the full-screen break on every connected display.
final class BreakOverlay {
    weak var scheduler: BreakScheduler?

    private var windows: [NSWindow] = []
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.windows.isEmpty else { return }
            self.closeWindows(animated: false)
            self.openWindows()
        }
    }

    func show() {
        guard windows.isEmpty else { return }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front == NSRunningApplication.current ? nil : front
        openWindows()
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Space and Escape skip (when allowed); swallow all other keys while the break is up.
            if event.keyCode == 49 || event.keyCode == 53, let scheduler = self?.scheduler, scheduler.canSkip() {
                scheduler.skip()
            }
            return nil
        }
    }

    func hide() {
        guard !windows.isEmpty else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        closeWindows(animated: true)
        previousApp?.activate(options: [])
        previousApp = nil
    }

    private func openWindows() {
        guard let scheduler else { return }
        for screen in NSScreen.screens {
            let window = BreakWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: BreakView(scheduler: scheduler, settings: scheduler.settings, stats: scheduler.stats))
            window.setFrame(screen.frame, display: true)
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }
        windows.first?.makeKey()
    }

    private func closeWindows(animated: Bool) {
        let closing = windows
        windows = []
        guard animated else {
            closing.forEach { $0.close() }
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.close() }
        })
    }
}
