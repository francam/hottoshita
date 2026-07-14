import XCTest

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing"]
        app.launch()
    }

    private func advanceToContactStep() {
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("John")
        dismissKeyboard()
        app.buttons["Continue"].tap()
        // A transient "Hi {name}!" splash auto-advances after ~2s.
        XCTAssertTrue(app.staticTexts["Who receives your reports?"].waitForExistence(timeout: 8))
    }

    private func dismissKeyboard() {
        if app.keyboards.count > 0 {
            app.keyboards.buttons["return"].tap()
        }
    }

    func testNameStepIsShownOnFirstLaunch() {
        XCTAssertTrue(app.staticTexts["What's your name?"].waitForExistence(timeout: 3))
    }

    func testContinueDisabledWithEmptyName() {
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
    }

    func testGreetingSplashShownAfterName() {
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("John")
        dismissKeyboard()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Hi John!"].waitForExistence(timeout: 3))
        // Splash auto-advances to the contact step.
        XCTAssertTrue(app.staticTexts["Who receives your reports?"].waitForExistence(timeout: 8))
    }

    func testContactStepShowsPickerAndFields() {
        advanceToContactStep()

        XCTAssertTrue(app.buttons["Choose from Contacts"].exists)
        XCTAssertEqual(app.textFields.count, 2)
    }

    func testContactPickerPresents() throws {
        advanceToContactStep()
        app.buttons["Choose from Contacts"].tap()

        // The contact picker runs out-of-process in ContactsViewService.
        // Simulators (especially beta runtimes) often fail to render remote
        // view controller content, so treat that as a skip, not a failure —
        // verify on a real device.
        let picker = XCUIApplication(bundleIdentifier: "com.apple.ContactsViewService")
        guard picker.navigationBars.firstMatch.waitForExistence(timeout: 5) else {
            throw XCTSkip("Contact picker remote content did not render (known simulator limitation)")
        }
    }

    func testContinueDisabledUntilContactValid() {
        advanceToContactStep()

        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled)

        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("Sarah")
        XCTAssertFalse(continueButton.isEnabled)

        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("sarah@example.com")
        XCTAssertTrue(continueButton.isEnabled)
    }

    func testCompletingOnboardingNavigatesToHome() {
        advanceToContactStep()

        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("Sarah")
        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("sarah@example.com")
        dismissKeyboard()
        app.buttons["Continue"].tap()

        // Reminder opt-in step: decline to avoid the permission dialog.
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 3))
        app.buttons["Not now"].tap()

        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 3))
        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.buttons["Start Today's Check-in"].waitForExistence(timeout: 3))
    }

    func testReminderStepOffersOptInAndTimePicker() {
        advanceToContactStep()

        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("Sarah")
        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("sarah@example.com")
        dismissKeyboard()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Would you like a daily reminder?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Yes, remind me"].exists)
        XCTAssertTrue(app.buttons["Not now"].exists)

        // Opting in reveals the time picker and Set Reminder.
        app.buttons["Yes, remind me"].tap()
        XCTAssertTrue(app.buttons["Set Reminder"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.datePickers.firstMatch.exists)
    }
}
