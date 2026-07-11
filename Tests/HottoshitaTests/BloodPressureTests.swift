import XCTest
@testable import Hottoshita

final class BloodPressureTests: XCTestCase {

    func testIsValidWithValidNumbers() {
        let bp = BloodPressure(systolic: "120", diastolic: "80")
        XCTAssertTrue(bp.isValid)
    }

    func testIsInvalidWithLetters() {
        let bp = BloodPressure(systolic: "abc", diastolic: "80")
        XCTAssertFalse(bp.isValid)
    }

    func testIsInvalidWhenEmpty() {
        let bp = BloodPressure()
        XCTAssertFalse(bp.isValid)
    }

    func testIsInvalidWithPartialInput() {
        let bp = BloodPressure(systolic: "120", diastolic: "")
        XCTAssertFalse(bp.isValid)
    }

    func testFormattedOutput() {
        let bp = BloodPressure(systolic: "120", diastolic: "80")
        XCTAssertEqual(bp.formatted, "120/80 mmHg")
    }
}
