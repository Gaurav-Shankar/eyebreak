import Foundation

/// macOS 12 has no SMAppService, so launch at login is a user LaunchAgent that opens the app bundle.
enum LaunchAtLogin {
    private static let label = "com.gauravshankar.eyebreak.launcher"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func set(_ enabled: Bool) {
        if enabled {
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
                "RunAtLoad": true,
            ]
            do {
                try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: plistURL)
            } catch {
                NSLog("EyeBreak: couldn't write launch agent: \(error)")
            }
        } else {
            try? FileManager.default.removeItem(at: plistURL)
        }
    }
}
