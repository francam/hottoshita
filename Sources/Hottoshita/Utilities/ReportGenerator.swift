import Foundation

enum ReportGenerator {
    static func generate(answers: CheckInAnswers, contactName: String, userName: String) -> String {
        let dateStr = answers.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())

        let greeting = String(format: NSLocalizedString("report.greeting", comment: ""), contactName)
        let intro = String(format: NSLocalizedString("report.intro", comment: ""), userName)
        let sleepLabel = NSLocalizedString("report.sleep", comment: "")
        let feelingLabel = NSLocalizedString("report.feeling", comment: "")
        let bpLabel = NSLocalizedString("report.bp", comment: "")
        let footer = NSLocalizedString("report.footer", comment: "")

        let sleepValue = NSLocalizedString(answers.sleep.rawValue, comment: "")
        let feelingsValue = answers.feelings.isEmpty
            ? NSLocalizedString("Not specified", comment: "")
            : answers.feelings.sorted().map { NSLocalizedString($0, comment: "") }.joined(separator: ", ")
        let bpValue = answers.tookBloodPressure
            ? answers.bloodPressure.formatted
            : NSLocalizedString("Not taken", comment: "")

        return """
        \(dateStr)

        \(greeting)

        \(intro)

        \(sleepLabel): \(sleepValue)
        \(feelingLabel): \(feelingsValue)
        \(bpLabel): \(bpValue)

        --
        \(footer)
        """
    }

    static func subject(for answers: CheckInAnswers) -> String {
        let dateStr = answers.date.formatted(.dateTime.month().day().year())
        return String(format: NSLocalizedString("report.subject", comment: ""), dateStr)
    }
}
