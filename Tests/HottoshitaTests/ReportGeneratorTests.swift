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

    func testBodyContainsAllSections() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: "Sarah", userName: "John")
        // All three data sections must be present
        XCTAssertTrue(body.contains("Sleep") || body.contains("睡眠"))
        XCTAssertTrue(body.contains("Feeling") || body.contains("気分"))
        XCTAssertTrue(body.contains("Blood Pressure") || body.contains("血圧"))
    }
}
