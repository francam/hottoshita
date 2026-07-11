import XCTest

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing"]
        app.launch()
    }

    func testOnboardingScreenIsShownOnFirstLaunch() {
        XCTAssertTrue(app.staticTexts["Welcome to Hottoshita"].exists)
    }

    func testGetStartedButtonDisabledWithEmptyFields() {
        XCTAssertFalse(app.buttons["Get Started"].isEnabled)
    }

    func testGetStartedButtonEnabledWithValidInput() {
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("Sarah")

        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("sarah@example.com")

        XCTAssertTrue(app.buttons["Get Started"].isEnabled)
    }

    func testCompletingOnboardingNavigatesToHome() {
        app.textFields.element(boundBy: 0).tap()
        app.textFields.element(boundBy: 0).typeText("Sarah")

        app.textFields.element(boundBy: 1).tap()
        app.textFields.element(boundBy: 1).typeText("sarah@example.com")

        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.staticTexts["Start Today's Check-in"].waitForExistence(timeout: 3))
    }
}
