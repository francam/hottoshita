import Foundation

@MainActor
final class CheckInStore: ObservableObject {
    /// Lets non-view code (ReminderScheduler call sites outside SwiftUI,
    /// like iCloudSettingsSync) check `submittedToday` without needing
    /// CheckInStore threaded through as a dependency everywhere.
    static private(set) weak var current: CheckInStore?

    @Published private(set) var entries: [CheckInAnswers] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("checkins.json")
        load()
        Self.current = self
        Task { [weak self] in await self?.syncWithCloud() }
    }

    var submittedToday: Bool {
        guard let latest = entries.last else { return false }
        return Calendar.current.isDateInToday(latest.date)
    }

    func save(_ answers: CheckInAnswers) {
        entries.append(answers)
        persist()
        CheckInCloudSync.shared.push(answers)
        rescheduleReminderIfNeeded()
    }

    /// An early check-in shouldn't still get nagged at by today's reminder —
    /// roll it to tomorrow instead of leaving it firing at the usual time.
    private func rescheduleReminderIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "reminderEnabled") else { return }
        let minutes = defaults.object(forKey: "reminderMinutes") as? Int ?? 9 * 60
        ReminderScheduler.scheduleNext(hour: minutes / 60, minute: minutes % 60, submittedToday: submittedToday)
    }

    func delete(_ entry: CheckInAnswers) {
        entries.removeAll { $0.id == entry.id }
        persist()
        CheckInCloudSync.shared.delete(id: entry.id)
    }

    /// Pulls remote entries from CloudKit (if iCloud sync is on) and merges
    /// them in: entries that don't exist locally yet (created on another
    /// device) are added; for entries that exist on both sides, `sent` is
    /// treated as monotonic — once true anywhere, true everywhere. Called
    /// at launch, and again right after sync is first turned on in
    /// Settings so pre-existing history backfills both ways.
    func syncWithCloud() async {
        let remote = await CheckInCloudSync.shared.fetchAll()
        guard !remote.isEmpty else { return }
        var changed = false
        for remoteEntry in remote {
            if let i = entries.firstIndex(where: { $0.id == remoteEntry.id }) {
                if remoteEntry.sent && !entries[i].sent {
                    entries[i].sent = true
                    changed = true
                }
            } else {
                entries.append(remoteEntry)
                changed = true
            }
        }
        guard changed else { return }
        entries.sort { $0.date < $1.date }
        persist()
    }

    /// Check-ins finished with "Done" (or a failed send) that were never
    /// emailed — the next send catches these up.
    func unsentEntries(excluding id: UUID? = nil) -> [CheckInAnswers] {
        entries.filter { !$0.sent && $0.id != id }
    }

    /// Marks a single entry as emailed (used when the user chose to send
    /// only today's report).
    func markSent(id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }), !entries[i].sent else { return }
        entries[i].sent = true
        persist()
        CheckInCloudSync.shared.push(entries[i])
    }

    /// Called after Mail confirms a send: everything unsent was included in
    /// that email, so mark it all as sent.
    func markAllUnsentAsSent() {
        guard entries.contains(where: { !$0.sent }) else { return }
        for i in entries.indices where !entries[i].sent {
            entries[i].sent = true
            CheckInCloudSync.shared.push(entries[i])
        }
        persist()
    }

    /// Erase All Data, this device's part: drops every entry and the
    /// history file. The iCloud copy is handled by DataEraser.
    func eraseLocal() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CheckInAnswers].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
