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

    func testHistoryRowCanBeDeleted() {
        app.buttons["Start Today's Check-in"].tap()
        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        app.buttons["History"].tap()
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        // Deleting asks for confirmation first.
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No Check-ins Yet"].waitForExistence(timeout: 3))

        // The deleted entry was today's — the home screen offers a fresh start.
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Start Today's Check-in"].waitForExistence(timeout: 3))
    }

    func testHistoryViewOpens() {
        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    }

    func testEraseAllDataReturnsToOnboarding() {
        // Some history first, so there's something to erase.
        app.buttons["Start Today's Check-in"].tap()
        app.buttons["Slept OK"].tap()
        app.buttons["Skip"].tap()
        app.buttons["No"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        app.buttons["Settings"].tap()
        tapEraseAllData()

        // Two confirmations before anything is deleted.
        XCTAssertTrue(app.alerts["Erase all your data?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.alerts["This can't be undone"].waitForExistence(timeout: 3))
        app.alerts.buttons["Erase Everything"].tap()

        // Back to first launch: onboarding, not Home.
        XCTAssertTrue(app.staticTexts["What's your name?"].waitForExistence(timeout: 10))
    }

    func testEraseAllDataCanBeCancelled() {
        app.buttons["Settings"].tap()
        tapEraseAllData()
        XCTAssertTrue(app.alerts["Erase all your data?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    func testAddingContactsStopsAtFive() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let add = app.buttons["Add Another Contact"]
        // The first contact plus four more.
        for n in 1...4 {
            var swipes = 0
            while !(add.exists && add.isHittable) && swipes < 6 { app.swipeUp(); swipes += 1 }
            add.tap()
            XCTAssertTrue(app.navigationBars["Add Contact"].waitForExistence(timeout: 3))
            app.textFields["addContact.name"].tap()
            app.textFields["addContact.name"].typeText("Person \(n)")
            app.textFields["addContact.email"].tap()
            app.textFields["addContact.email"].typeText("p\(n)@example.com")
            app.buttons["Add"].tap()
            XCTAssertTrue(app.staticTexts["Person \(n)"].waitForExistence(timeout: 3))
        }
        XCTAssertFalse(add.exists, "no more than five contacts")

        // Removing one brings the button back.
        app.buttons["Remove Person 4"].tap()
        XCTAssertFalse(app.staticTexts["Person 4"].exists)
        XCTAssertTrue(add.waitForExistence(timeout: 3))

        // Saved with Settings; Cancel would have discarded them.
        app.buttons["Save"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Person 3"].waitForExistence(timeout: 3))
    }

    func testAddedContactIsDiscardedOnCancel() {
        app.buttons["Settings"].tap()
        let add = app.buttons["Add Another Contact"]
        var swipes = 0
        while !(add.exists && add.isHittable) && swipes < 6 { app.swipeUp(); swipes += 1 }
        add.tap()
        app.textFields["addContact.name"].tap()
        app.textFields["addContact.name"].typeText("Tom")
        app.textFields["addContact.email"].tap()
        app.textFields["addContact.email"].typeText("tom@example.com")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Tom"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Tom"].exists)
    }

    /// Settings is a lazy list: the Erase row only exists once scrolled to.
    private func tapEraseAllData() {
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let erase = app.buttons["Erase All Data"]
        var swipes = 0
        while !(erase.exists && erase.isHittable) && swipes < 8 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(erase.isHittable)
        erase.tap()
    }

    func testSettingsViewOpens() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}
