import SwiftUI

struct RootView: View {
    @AppStorage("contactName") private var contactName = ""
    @AppStorage("contactEmail") private var contactEmail = ""

    @AppStorage("userName") private var userName = ""
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60

    @EnvironmentObject private var store: CheckInStore
    @Environment(\.scenePhase) private var scenePhase

    private var isOnboarded: Bool { !userName.isEmpty && !contactName.isEmpty && !contactEmail.isEmpty }

    var body: some View {
        Group {
            if isOnboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        // The reminder is a one-shot trigger, not a repeating one (see
        // ReminderScheduler), so once it fires it needs a fresh successor
        // scheduled — foregrounding the app is the natural point to do that.
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            // A history write that failed (storage full) gets another try.
            store.retryIfSaveFailed()
            guard reminderEnabled else { return }
            ReminderScheduler.scheduleNext(hour: reminderMinutes / 60, minute: reminderMinutes % 60, submittedToday: store.submittedToday)
        }
    }
}
