import SwiftUI

@main
struct HottoshitaApp: App {
    @StateObject private var store = CheckInStore()
    @StateObject private var appTheme = AppTheme()

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--reset-for-testing") {
            if let domain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }
            // Also clear persisted check-in history, or submittedToday leaks
            // between test runs.
            let storeURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("checkins.json")
            try? FileManager.default.removeItem(at: storeURL)
        }
        if args.contains("--skip-onboarding") {
            UserDefaults.standard.set("Test User", forKey: "userName")
            UserDefaults.standard.set("Test Contact", forKey: "contactName")
            UserDefaults.standard.set("test@example.com", forKey: "contactEmail")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appTheme)
        }
    }
}
