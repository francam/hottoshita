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
