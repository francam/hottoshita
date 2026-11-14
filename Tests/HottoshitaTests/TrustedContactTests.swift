import XCTest
@testable import Hottoshita

final class TrustedContactTests: XCTestCase {

    private let tom = TrustedContact(name: "Tom", email: "tom@example.com")
    private let ana = TrustedContact(name: "Ana", email: "ana@example.com")

    // MARK: - Recipients

    func testSingleContactIsAddressedDirectlyAndByName() {
        let recipients = ReportRecipients(primaryName: "Sarah", primaryEmail: "sarah@example.com", additional: [])
        XCTAssertEqual(recipients.emails, ["sarah@example.com"])
        XCTAssertFalse(recipients.usesBCC)
        XCTAssertEqual(recipients.greetingName, "Sarah")
    }

    func testSeveralContactsUseBCCAndAGenericGreeting() {
        let recipients = ReportRecipients(primaryName: "Sarah", primaryEmail: "sarah@example.com", additional: [tom, ana])
        XCTAssertEqual(recipients.emails, ["sarah@example.com", "tom@example.com", "ana@example.com"])
        XCTAssertTrue(recipients.usesBCC)
        XCTAssertNil(recipients.greetingName, "naming everyone would reveal the BCC recipients")
        XCTAssertTrue(recipients.displayNames.contains("Sarah"))
        XCTAssertTrue(recipients.displayNames.contains("Ana"))
    }

    // MARK: - Storage

    func testRoundTrip() {
        let decoded = TrustedContacts.decode(TrustedContacts.encode([tom, ana]))
        XCTAssertEqual(decoded, [tom, ana])
    }

    func testEmptyOrInvalidStorageDecodesToNoContacts() {
        XCTAssertEqual(TrustedContacts.decode(""), [])
        XCTAssertEqual(TrustedContacts.decode("not json"), [])
    }

    func testAtMostFiveContactsInTotal() {
        let many = (1...8).map { TrustedContact(name: "C\($0)", email: "c\($0)@example.com") }
        // The first contact is stored separately, so four more at most.
        XCTAssertEqual(TrustedContacts.decode(TrustedContacts.encode(many)).count, TrustedContacts.maximum - 1)
        XCTAssertEqual(TrustedContacts.maximum, 5)
    }

    // MARK: - Report greeting

    func testReportGreetsSeveralRecipientsGenerically() {
        let body = ReportGenerator.generate(answers: CheckInAnswers(), contactName: nil, userName: "John")
        XCTAssertTrue(body.contains("Hello,"))
        XCTAssertFalse(body.contains("Sarah"))
    }
}
