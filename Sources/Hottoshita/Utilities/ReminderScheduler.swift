import Foundation
import UserNotifications

enum ReminderScheduler {
    static let notificationID = "daily-checkin-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedules (or reschedules) the repeating daily reminder.
    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.title")
        content.body = String(localized: "reminder.body")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
