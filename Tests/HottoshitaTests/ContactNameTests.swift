import XCTest
@testable import Hottoshita

final class ContactNameTests: XCTestCase {

    func testEnglishUsesTheGivenName() {
        XCTAssertEqual(ContactName.addressName(given: "Miguel", family: "Franca", full: "Miguel Franca", japanese: false), "Miguel")
    }

    func testJapaneseUsesTheFamilyName() {
        // The greeting adds さん: 「田中さん」.
        XCTAssertEqual(ContactName.addressName(given: "花子", family: "田中", full: "田中 花子", japanese: true), "田中")
    }

    func testFallsBackToTheOtherPartThenTheFullName() {
        XCTAssertEqual(ContactName.addressName(given: "", family: "Tanaka", full: "Tanaka", japanese: false), "Tanaka")
        XCTAssertEqual(ContactName.addressName(given: "Hanako", family: "", full: "Hanako", japanese: true), "Hanako")
        XCTAssertEqual(ContactName.addressName(given: " ", family: "", full: "Acme Care", japanese: false), "Acme Care")
    }
}
