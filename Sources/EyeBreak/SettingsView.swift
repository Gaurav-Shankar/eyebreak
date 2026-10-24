import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var stats: Stats
    let scheduler: BreakScheduler

    private let minutesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = 240
        formatter.allowsFloats = false
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Schedule") {
                HStack {
                    Text("Break every")
                    TextField("", value: $settings.workMinutes, formatter: minutesFormatter)
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.workMinutes, in: 1...240).labelsHidden()
                    Text("minutes")
                }
                Picker("Break length", selection: $settings.breakSeconds) {
                    ForEach(Settings.breakLengthOptions, id: \.self) { seconds in
                        Text(Notifier.describe(TimeInterval(seconds))).tag(seconds)
                    }
                }
                .frame(width: 260)
                Picker("Heads-up", selection: $settings.headsUpSeconds) {
                    ForEach(Settings.headsUpOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? "Off" : "\(seconds) seconds before").tag(seconds)
                    }
                }
                .frame(width: 260)
            }

            section("Break") {
                Picker("Style", selection: $settings.breakStyle) {
                    ForEach(BreakStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Picker("Allow skipping", selection: $settings.skipMode) {
                    ForEach(SkipMode.allCases) { Text($0.label).tag($0) }
                }
                .frame(width: 260)
                HStack {
                    Text("Message")
                    TextField("Look at something 20 feet away", text: $settings.message)
                }
                HStack(spacing: 10) {
                    Text("Colours")
                    ForEach(Theme.allCases) { theme in
                        swatch(theme)
                    }
                }
                Button("Preview Break") { scheduler.takeBreakNow() }
            }

            section("Sound") {
                Picker("Chime", selection: $settings.chime) {
                    Text("None").tag("")
                    ForEach(Chime.names, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 260)
                .onChange(of: settings.chime) { Chime.play($0) }
                Toggle("Play when a break starts", isOn: $settings.chimeAtStart)
                Toggle("Play when a break ends", isOn: $settings.chimeAtEnd)
            }

            section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { LaunchAtLogin.set($0) }
                Toggle("Show countdown in menu bar", isOn: $settings.showCountdownInMenuBar)
            }

            section("Stats") {
                Text("\(stats.breaksTaken) breaks taken · \(stats.skips) skipped")
                Text("Current streak \(stats.streak) · Best \(stats.bestStreak)")
                Button("Reset Stats") { stats.reset() }
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func swatch(_ theme: Theme) -> some View {
        Circle()
            .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: settings.theme == theme ? 2.5 : 0).padding(-3))
            .help(theme.label)
            .onTapGesture { settings.theme = theme }
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init(scheduler: BreakScheduler) {
        let hosting = NSHostingView(rootView: SettingsView(settings: scheduler.settings, stats: scheduler.stats, scheduler: scheduler))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "EyeBreak Settings"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
