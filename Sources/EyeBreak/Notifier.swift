import Foundation
import UserNotifications

/// Heads-up and notification-only breaks.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    weak var scheduler: BreakScheduler?

    private let center = UNUserNotificationCenter.current()
    private let headsUpID = "headsUp"
    private let breakID = "break"

    func setup() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let skip = UNNotificationAction(identifier: "skip", title: "Skip this break")
        let snooze = UNNotificationAction(identifier: "snooze", title: "Snooze 30 minutes")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "headsUp", actions: [skip, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: "headsUpNoSkip", actions: [snooze], intentIdentifiers: []),
        ])
    }

    func headsUp(in seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Break in \(seconds) seconds"
        content.body = "Get ready to rest your eyes."
        content.categoryIdentifier = Settings.shared.skipMode == .never ? "headsUpNoSkip" : "headsUp"
        post(content, id: headsUpID)
    }

    func breakStarted() {
        let settings = Settings.shared
        let content = UNMutableNotificationContent()
        content.title = "Time for a break"
        content.body = "\(settings.message) for \(Self.describe(settings.breakDuration))."
        if settings.chime.isEmpty || !settings.chimeAtStart { content.sound = .default }
        post(content, id: breakID)
    }

    func clearHeadsUp() {
        center.removeDeliveredNotifications(withIdentifiers: [headsUpID])
    }

    private func post(_ content: UNMutableNotificationContent, id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    static func describe(_ duration: TimeInterval) -> String {
        let s = Int(duration)
        if s < 60 { return "\(s) seconds" }
        let m = s / 60
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            switch response.actionIdentifier {
            case "skip": self?.scheduler?.skipUpcoming()
            case "snooze": self?.scheduler?.snooze(for: 30 * 60)
            default: break
            }
        }
        completionHandler()
    }
}
