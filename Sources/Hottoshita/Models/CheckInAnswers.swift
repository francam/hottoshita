import Foundation

enum SleepRating: String, CaseIterable, Hashable, Codable {
    case deeply = "Slept deeply"
    case ok = "Slept OK"
    case barely = "Barely slept"
    case none = "Didn't sleep"
}

struct BloodPressure: Codable {
    var systolic: String = ""
    var diastolic: String = ""

    /// Both readings entered and within a physiologically plausible range —
    /// generous bounds; the point is to reject typos like 999 or 2, not to
    /// second-guess unusual but real readings.
    var isValid: Bool {
        guard let s = Int(systolic), let d = Int(diastolic) else { return false }
        return (40...300).contains(s) && (20...200).contains(d)
    }

    var formatted: String { "\(systolic)/\(diastolic) mmHg" }
}

struct CheckInAnswers: Codable, Identifiable {
    var id: UUID = UUID()
    var sleep: SleepRating = .ok
    var feelings: [String] = []
    var tookBloodPressure: Bool = false
    var bloodPressure: BloodPressure = BloodPressure()
    var date: Date = Date()
}

let feelingOptions: [String] = ["Good", "Tired", "Dizzy", "Heavy", "Anxious", "Happy", "Sad", "Calm"]
