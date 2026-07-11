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

    var isValid: Bool { Int(systolic) != nil && Int(diastolic) != nil }
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
