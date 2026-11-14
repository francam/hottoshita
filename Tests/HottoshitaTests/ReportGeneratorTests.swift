import XCTest
@testable import Hottoshita

final class ReportGeneratorTests: XCTestCase {

    func testSubjectContainsDate() {
        let answers = CheckInAnswers()
        let subject = ReportGenerator.subject(for: answers)
        XCTAssertFalse(subject.isEmpty)
        // Subject should contain the formatted date
        let dateStr = answers.date.formatted(.dateTime.month().day().year())
        XCTAssertTrue(subject.contains(dateStr))
    }

    func testBodyContainsContactName() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("Sarah"))
    }

    func testBodyContainsUserName() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("John"))
    }

    func testBodyContainsSleepValue() {
        var answers = CheckInAnswers()
        answers.sleep = .deeply
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("Slept deeply"))
    }

    func testBodyContainsBloodPressure() {
        var answers = CheckInAnswers()
        answers.tookBloodPressure = true
        answers.bloodPressure = BloodPressure(systolic: "120", diastolic: "80")
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("120/80"))
    }

    func testBodyShowsNotTakenWhenBPSkipped() {
        var answers = CheckInAnswers()
        answers.tookBloodPressure = false
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("Not taken"))
    }

    func testBodyContainsFeelings() {
        var answers = CheckInAnswers()
        answers.feelings = ["Happy", "Calm"]
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("Happy"))
        XCTAssertTrue(body.contains("Calm"))
    }

    func testBodyShowsNotSpecifiedWhenNoFeelings() {
        var answers = CheckInAnswers()
        answers.feelings = []
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("Not specified"))
    }

    func testBodyIsAnHTMLEmailWithTheLogo() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.hasPrefix("<!doctype html>"))
        XCTAssertTrue(body.contains(ReportGenerator.logoURL))
        // The header's name is text, so it shows even with images blocked.
        XCTAssertTrue(body.contains(">hottoshita</td>"))
    }

    func testFooterLinksToTheAppStore() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("href=\"\(ReportGenerator.appStoreURL)\""))
        XCTAssertTrue(body.contains(ReportGenerator.escape(NSLocalizedString("report.footer", comment: ""))))
    }

    func testSeveralRecipientsGetAGenericGreeting() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: nil, userName: "John")
        XCTAssertTrue(body.contains(ReportGenerator.escape(NSLocalizedString("report.greeting.everyone", comment: ""))))
        XCTAssertFalse(body.contains("Sarah"))
    }

    func testNamesAreEscaped() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "<b>Tom</b> & Co", userName: "John")
        XCTAssertTrue(body.contains("&lt;b&gt;Tom&lt;/b&gt; &amp; Co"))
        XCTAssertFalse(body.contains("<b>Tom</b>"))
    }

    func testEscapeCoversQuotes() {
        XCTAssertEqual(ReportGenerator.escape(#"O'Brien "Jr""#), "O&#39;Brien &quot;Jr&quot;")
    }

    func testEarlierUnsentCheckInsAreIncluded() {
        var earlier = CheckInAnswers()
        earlier.date = Date().addingTimeInterval(-86_400)
        earlier.sleep = .barely
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John",
                                            previousUnsent: [earlier])
        XCTAssertTrue(body.contains(NSLocalizedString("report.previous", comment: "")))
        XCTAssertTrue(body.contains("Barely slept"))
        // Condensed: a short date, the answers on one line.
        XCTAssertTrue(body.contains(earlier.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())))
    }

    func testReadingNeverWraps() {
        var answers = CheckInAnswers()
        answers.tookBloodPressure = true
        answers.bloodPressure = BloodPressure(systolic: "128", diastolic: "82")
        let body = ReportGenerator.generate(answers: answers, contactName: "Sarah", userName: "John")
        XCTAssertTrue(body.contains("white-space:nowrap\">128/82 mmHg"))
    }

    func testBodyContainsAllSections() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        // All three data sections must be present
        XCTAssertTrue(body.contains("Sleep") || body.contains("睡眠"))
        XCTAssertTrue(body.contains("Feeling") || body.contains("気分"))
        XCTAssertTrue(body.contains("Blood Pressure") || body.contains("血圧"))
    }
}
