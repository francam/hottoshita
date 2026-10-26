import Foundation

/// Erase All Data (Settings). Deleting the app isn't enough once iCloud sync
/// has been on: a reinstall pulls the synced copy straight back. This removes
/// the iCloud copy first, then everything on this device, leaving the app as
/// on first launch (it returns to onboarding).
@MainActor
enum DataEraser {
    /// The UserDefaults keys the app writes (all @AppStorage).
    private static let defaultsKeys = [
        "userName", "contactName", "contactEmail",
        "colorTheme", "reminderEnabled", "reminderMinutes",
        TrustedContacts.storageKey,
    ]

    /// Returns false — with nothing erased — if iCloud was reachable but its
    /// copy couldn't be deleted (e.g. offline), so the user isn't left
    /// believing data is gone while a copy remains to come back.
    static func eraseEverything(store: CheckInStore, appTheme: AppTheme) async -> Bool {
        guard await CheckInCloudSync.shared.deleteAll() else { return false }

        // Key-value store before UserDefaults: with the sync switch gone,
        // clearing the local values below can't be pushed back up.
        iCloudSettingsSync.shared.eraseCloudCopy()
        store.eraseLocal()
        ReminderScheduler.cancel()
        appTheme.theme = .default
        appTheme.updateAppIcon()
        // removeObject per key (not removePersistentDomain) so @AppStorage
        // observers see each change and RootView falls back to onboarding.
        for key in defaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return true
    }
}
