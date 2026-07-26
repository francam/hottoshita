import Foundation

/// Mirrors a small set of UserDefaults keys to `NSUbiquitousKeyValueStore`
/// so they sync between the user's own devices signed into the same Apple
/// ID. Entirely optional and best-effort: if iCloud isn't available the app
/// keeps working exactly as before, purely on local UserDefaults.
///
/// `isEnabled` itself lives only in the key-value store (not mirrored), so
/// turning sync on from any one device turns it on everywhere once that
/// device's change propagates.
@MainActor
final class iCloudSettingsSync {
    static let shared = iCloudSettingsSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private let syncedKeys = [
        "userName", "contactName", "contactEmail",
        "colorTheme", "reminderEnabled", "reminderMinutes",
    ]

    /// Guards against the write-back loop: applying a remote value to
    /// UserDefaults triggers `UserDefaults.didChangeNotification`, which
    /// would otherwise immediately re-push that same value to the cloud.
    private var isApplyingRemoteChange = false

    var isEnabled: Bool {
        get { store.bool(forKey: "iCloudSyncEnabled") }
        set {
            store.set(newValue, forKey: "iCloudSyncEnabled")
            store.synchronize()
            if newValue { pushAllLocalToCloud() }
        }
    }

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(localChange(_:)),
            name: UserDefaults.didChangeNotification, object: defaults
        )
        store.synchronize()
        if isEnabled { applyRemoteValues(for: syncedKeys) }
    }

    @objc private func externalChange(_ note: Notification) {
        guard isEnabled else { return }
        let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        applyRemoteValues(for: changedKeys.filter(syncedKeys.contains))
    }

    @objc private func localChange(_ note: Notification) {
        guard isEnabled, !isApplyingRemoteChange else { return }
        pushAllLocalToCloud()
    }

    private func applyRemoteValues(for keys: [String]) {
        guard !keys.isEmpty else { return }
        isApplyingRemoteChange = true
        for key in keys {
            guard let value = store.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }
        isApplyingRemoteChange = false

        // Settings staging (see SettingsView) only reschedules the local
        // notification on Save, so a reminder change arriving from another
        // device needs to be applied explicitly here too.
        guard keys.contains("reminderEnabled") || keys.contains("reminderMinutes") else { return }
        if defaults.bool(forKey: "reminderEnabled") {
            let minutes = defaults.object(forKey: "reminderMinutes") as? Int ?? 9 * 60
            ReminderScheduler.schedule(hour: minutes / 60, minute: minutes % 60)
        } else {
            ReminderScheduler.cancel()
        }
    }

    private func pushAllLocalToCloud() {
        for key in syncedKeys {
            guard let value = defaults.object(forKey: key) else { continue }
            store.set(value, forKey: key)
        }
        store.synchronize()
    }
}
