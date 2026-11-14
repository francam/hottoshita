import UIKit
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

    // MARK: - Photos (1.5)

    func testContactsSavedBeforePhotosStillDecode() {
        let old = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","name":"Tom","email":"tom@example.com"}]"#
        let list = TrustedContacts.decode(old)
        XCTAssertEqual(list.map(\.name), ["Tom"])
        XCTAssertNil(list[0].photo)
    }

    func testFirstContactsPhotoSurvivesSplitAndList() {
        let photo = Data([1, 2, 3])
        let stored = TrustedContacts.split([TrustedContact(name: "Sarah", email: "s@example.com", photo: photo),
                                            TrustedContact(name: "Tom", email: "t@example.com")])
        XCTAssertEqual(stored.photo, photo)
        let back = TrustedContacts.list(primaryName: stored.name, primaryEmail: stored.email,
                                        primaryPhoto: stored.photo, additionalJSON: stored.additionalJSON)
        XCTAssertEqual(back.first?.photo, photo)
        XCTAssertEqual(back.count, 2)
    }

    func testLeavingSomeoneOutOfOneSend() {
        let everyone = ReportRecipients(primaryName: "Sarah", primaryEmail: "Sarah@Example.com",
                                        additional: [TrustedContact(name: "Tom", email: "tom@example.com"),
                                                     TrustedContact(name: "Emily", email: "emily@example.com")])
        let some = everyone.excluding(emails: ["sarah@example.com"])
        XCTAssertEqual(some.names, ["Tom", "Emily"])
        XCTAssertTrue(some.usesBCC)
        let one = everyone.excluding(emails: ["sarah@example.com", "emily@example.com"])
        XCTAssertEqual(one.emails, ["tom@example.com"])
        // Down to one: greeted by name and sent To, not BCC.
        XCTAssertEqual(one.greetingName, "Tom")
        XCTAssertFalse(one.usesBCC)
    }

    func testInitials() {
        XCTAssertEqual(ContactAvatar.initials(of: "Sarah Smith"), "SS")
        XCTAssertEqual(ContactAvatar.initials(of: "tom"), "T")
        XCTAssertEqual(ContactAvatar.initials(of: "由美"), "由")
        XCTAssertEqual(ContactAvatar.initials(of: "  "), "?")
    }

    func testPhotosAreStoredSmall() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        let data = try XCTUnwrap(ContactPhoto.squared(big))
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(image.size.width * image.scale, ContactPhoto.side)
        XCTAssertEqual(image.size.height * image.scale, ContactPhoto.side)
        XCTAssertLessThan(data.count, 20_000)
    }
}
