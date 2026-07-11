import XCTest

final class HomeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing", "--skip-onboarding"]
        app.launch()
    }

    func testHomeShowsGreetingAndDate() {
        // Greeting exists (one of the three time-based variants)
        let greetings = ["Good morning!", "Good afternoon!", "Good evening!"]
        let greetingExists = greetings.contains { app.staticTexts[$0].exists }
        XCTAssertTrue(greetingExists)

        // Date text exists (non-empty)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'June'")).allElementsBoundByIndex.isEmpty)
    }

    func testHistoryButtonExists() {
        XCTAssertTrue(app.buttons["clock.arrow.circlepath"].exists ||
                      app.navigationBars.buttons.element(boundBy: 0).exists)
    }

    func testSettingsButtonExists() {
        XCTAssertTrue(app.buttons["gear"].exists ||
                      app.navigationBars.buttons["gear"].exists)
    }

    func testAlreadySubmittedBannerAppearsAfterCheckIn() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Already submitted today!"].waitForExistence(timeout: 3))
    }

    func testHistoryViewOpens() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    }

    func testSettingsViewOpens() {
        app.navigationBars.buttons["gear"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}
