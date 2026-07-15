import Foundation

@MainActor
final class CheckInStore: ObservableObject {
    @Published private(set) var entries: [CheckInAnswers] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("checkins.json")
        load()
    }

    var submittedToday: Bool {
        guard let latest = entries.last else { return false }
        return Calendar.current.isDateInToday(latest.date)
    }

    func save(_ answers: CheckInAnswers) {
        entries.append(answers)
        persist()
    }

    func delete(_ entry: CheckInAnswers) {
        entries.removeAll { $0.id == entry.id }
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
    }

    /// Called after Mail confirms a send: everything unsent was included in
    /// that email, so mark it all as sent.
    func markAllUnsentAsSent() {
        guard entries.contains(where: { !$0.sent }) else { return }
        for i in entries.indices where !entries[i].sent {
            entries[i].sent = true
        }
        persist()
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
