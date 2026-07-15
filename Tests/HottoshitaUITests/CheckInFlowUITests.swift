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

        // Both fields and the Skip button must be fully on-screen while the
        // keyboard is up — the fields row used to overflow in portrait and
        // push the diastolic field off the right edge.
        XCTAssertEqual(app.textFields.count, 2)
        XCTAssertTrue(app.textFields.element(boundBy: 0).isHittable)
        XCTAssertTrue(app.textFields.element(boundBy: 1).isHittable)
        XCTAssertTrue(app.buttons["Skip"].isHittable)
    }

    func testSummaryShowsSelectedSleepValue() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Barely slept"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()

        XCTAssertTrue(app.staticTexts["Barely slept"].waitForExistence(timeout: 3))
    }

    func testLandscapeFlowFitsWithoutScrolling() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        app.buttons["Start Today's Check-in"].tap()

        // Every step's controls must be tappable without scrolling —
        // including the last choice at the bottom of the list.
        XCTAssertTrue(app.buttons["Didn't sleep"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Didn't sleep"].isHittable)
        app.buttons["Slept OK"].tap()

        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Skip"].isHittable)
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["No"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["No"].isHittable)
        app.buttons["No"].tap()

        // Summary: all three actions reachable without scrolling.
        XCTAssertTrue(app.buttons["Send Report"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Send Report"].isHittable)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        XCTAssertTrue(app.buttons["Start Over"].isHittable)
    }

    func testUnsentCheckInsAreTrackedAndIncludedInNextSend() {
        // Finish a check-in with "Done" — recorded, but never emailed.
        app.buttons["Start Today's Check-in"].tap()
        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        // History flags it and offers to send the backlog directly.
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Not sent yet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Send Unsent Check-ins"].exists)
        app.buttons["Done"].tap()

        // The next check-in's summary points out the pending ones.
        XCTAssertTrue(app.buttons["Submit again anyway"].waitForExistence(timeout: 3))
        app.buttons["Submit again anyway"].tap()
        app.buttons["Slept deeply"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()
        XCTAssertTrue(app.staticTexts["Some earlier check-ins have not been sent yet."]
            .waitForExistence(timeout: 3))
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
