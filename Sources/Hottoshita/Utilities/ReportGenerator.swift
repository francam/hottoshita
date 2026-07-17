import Foundation

enum ReportGenerator {
    static func generate(answers: CheckInAnswers, contactName: String, userName: String,
                         previousUnsent: [CheckInAnswers] = []) -> String {
        let dateStr = answers.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())

        let greeting = String(format: NSLocalizedString("report.greeting", comment: ""), contactName)
        let intro = String(format: NSLocalizedString("report.intro", comment: ""), userName)
        let footer = NSLocalizedString("report.footer", comment: "")

        var body = """
        \(dateStr)

        \(greeting)

        \(intro)

        \(answersBlock(for: answers))
        """

        // Catch up on check-ins that were finished but never emailed.
        let backlog = previousUnsent.sorted { $0.date < $1.date }
        if !backlog.isEmpty {
            body += "\n\n" + NSLocalizedString("report.previous", comment: "") + "\n"
            for entry in backlog {
                let entryDate = entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
                body += "\n\(entryDate)\n\(answersBlock(for: entry))\n"
            }
        }

        body += "\n\n--\n\(footer)"
        return body
    }

    private static func answersBlock(for answers: CheckInAnswers) -> String {
        let sleepLabel = NSLocalizedString("report.sleep", comment: "")
        let feelingLabel = NSLocalizedString("report.feeling", comment: "")
        let bpLabel = NSLocalizedString("report.bp", comment: "")

        let sleepValue = NSLocalizedString(answers.sleep?.rawValue ?? "", comment: "")
        let feelingsValue = answers.feelings.isEmpty
            ? NSLocalizedString("Not specified", comment: "")
            : answers.feelings.sorted().map { NSLocalizedString($0, comment: "") }.joined(separator: ", ")
        let bpValue = (answers.tookBloodPressure ?? false) && answers.bloodPressure.isValid
            ? answers.bloodPressure.formatted
            : NSLocalizedString("Not taken", comment: "")

        return """
        \(sleepLabel): \(sleepValue)
        \(feelingLabel): \(feelingsValue)
        \(bpLabel): \(bpValue)
        """
    }

    static func subject(for answers: CheckInAnswers) -> String {
        let dateStr = answers.date.formatted(.dateTime.month().day().year())
        return String(format: NSLocalizedString("report.subject", comment: ""), dateStr)
    }
}
