import XCTest

final class CheckInFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing", "--skip-onboarding"]
        app.launch()
    }

    func testCheckInFlowOpens() {
        app.buttons["Start Today's Check-in"].tap()
        XCTAssertTrue(app.staticTexts["Question 1 of 3"].waitForExistence(timeout: 3))
    }

    func testSleepQuestionShowsAllOptions() {
        app.buttons["Start Today's Check-in"].tap()
        XCTAssertTrue(app.buttons["Slept deeply"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Slept OK"].exists)
        XCTAssertTrue(app.buttons["Barely slept"].exists)
        XCTAssertTrue(app.buttons["Didn't sleep"].exists)
    }

    func testBackButtonReturnsToPreviousQuestion() {
        app.buttons["Start Today's Check-in"].tap()
        app.buttons["Slept OK"].tap()

        XCTAssertTrue(app.staticTexts["Question 2 of 3"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Question 1 of 3"].waitForExistence(timeout: 3))
    }

    func testCancelDismissesFlow() {
        app.buttons["Start Today's Check-in"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Start Today's Check-in"].waitForExistence(timeout: 3))
    }

    func testCompleteFlowWithoutBloodPressure() {
        app.buttons["Start Today's Check-in"].tap()

        // Sleep
        app.buttons["Slept OK"].tap()

        // Feeling — skip
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3))
        app.buttons["Skip"].tap()

        // Blood pressure — No
        XCTAssertTrue(app.buttons["No"].waitForExistence(timeout: 3))
        app.buttons["No"].tap()

        // Summary
        XCTAssertTrue(app.staticTexts["Check-in Complete"].waitForExistence(timeout: 3))
    }

    func testCompleteFlowReachingBloodPressureInput() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Slept deeply"].tap()
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["Yes"].waitForExistence(timeout: 3))
        app.buttons["Yes"].tap()

        XCTAssertTrue(app.staticTexts["Question 4 of 4"].waitForExistence(timeout: 3))
    }

    func testSummaryShowsSelectedSleepValue() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Barely slept"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()

        XCTAssertTrue(app.staticTexts["Barely slept"].waitForExistence(timeout: 3))
    }

    func testStartOverResetsFlow() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()

        XCTAssertTrue(app.buttons["Start Over"].waitForExistence(timeout: 3))
        app.buttons["Start Over"].tap()

        XCTAssertTrue(app.staticTexts["Question 1 of 3"].waitForExistence(timeout: 3))
    }
}
