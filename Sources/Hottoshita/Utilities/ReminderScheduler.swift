import Foundation
import UserNotifications

enum ReminderScheduler {
    static let notificationID = "daily-checkin-reminder"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedules the next occurrence of the daily reminder: today at
    /// hour:minute, unless that time already passed today or today's
    /// check-in is already done, in which case it rolls to tomorrow.
    ///
    /// Deliberately a one-shot trigger recomputed from scratch each call,
    /// not a single `repeats: true` trigger — that's what makes "skip
    /// today's reminder because I already checked in" possible at all.
    /// Call this whenever reminder settings change, a check-in is saved, or
    /// the app becomes active (so a one-shot that already fired gets a
    /// fresh successor).
    static func scheduleNext(hour: Int, minute: Int, submittedToday: Bool) {
        let calendar = Calendar.current
        let now = Date()
        guard var target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return }
        if submittedToday || target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }

        let content = UNMutableNotificationContent()
        // Translated when the notification is delivered, not now: a
        // language change before it fires (without opening the app, which
        // would reschedule it) still shows it in the new language.
        content.title = NSString.localizedUserNotificationString(forKey: "reminder.title", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "reminder.body", arguments: nil)
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
