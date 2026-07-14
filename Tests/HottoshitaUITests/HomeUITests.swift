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
        // Greeting includes the user's name, e.g. "Good evening, Test User!"
        let greeting = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Good' AND label CONTAINS 'Test User'")
        ).firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 3))

        // Date text shows the current month
        let month = Date().formatted(.dateTime.month(.wide))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", month)
        ).firstMatch.exists)
    }

    func testHistoryButtonExists() {
        XCTAssertTrue(app.buttons["History"].exists)
    }

    func testSettingsButtonExists() {
        XCTAssertTrue(app.buttons["Settings"].exists)
    }

    func testAlreadySubmittedBannerAppearsAfterCheckIn() {
        app.buttons["Start Today's Check-in"].tap()

        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Already submitted today!"].waitForExistence(timeout: 3))

        // The banner must not push the bottom actions off-screen.
        XCTAssertTrue(app.buttons["History"].isHittable)
        XCTAssertTrue(app.buttons["Settings"].isHittable)
    }

    func testLandscapeShowsAllButtons() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // Landscape uses a side-by-side layout; every control must be
        // tappable without scrolling.
        XCTAssertTrue(app.buttons["Start Today's Check-in"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Start Today's Check-in"].isHittable)
        XCTAssertTrue(app.buttons["History"].isHittable)
        XCTAssertTrue(app.buttons["Settings"].isHittable)
    }

    func testHistoryViewOpens() {
        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    }

    func testSettingsViewOpens() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}
