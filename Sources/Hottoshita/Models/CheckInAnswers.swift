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
    var sleep: SleepRating? = nil
    var feelings: [String] = []
    var tookBloodPressure: Bool? = nil
    var bloodPressure: BloodPressure = BloodPressure()
    var date: Date = Date()

    /// Whether this check-in has been emailed to the contact. Stored as an
    /// optional so history files written before the flag existed still decode
    /// (missing key → nil → treated as not sent).
    private var sentFlag: Bool?
    var sent: Bool {
        get { sentFlag ?? false }
        set { sentFlag = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case id, sleep, feelings, tookBloodPressure, bloodPressure, date
        case sentFlag = "sent"
    }
}

let feelingOptions: [String] = ["Good", "Tired", "Dizzy", "Heavy", "Anxious", "Happy", "Sad", "Calm"]
