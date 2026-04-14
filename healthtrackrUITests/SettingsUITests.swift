import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))
        element(AccessibilityID.settingsButton, in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() {
        let app = launchApp()
        openSettings(app)

        XCTAssertTrue(app.staticTexts["Version"].exists, "Version row should be visible in settings")

        app.buttons["Done"].tap()

        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsSignOutButton() {
        let app = launchApp()
        openSettings(app)

        let signOutButton = element(AccessibilityID.signOutButton, in: app)
        XCTAssertTrue(signOutButton.exists, "Sign Out button should be visible in settings")
    }

    @MainActor
    func testSettingsShowsHealthPermissionsSection() {
        let app = launchApp()
        openSettings(app)

        XCTAssertTrue(app.staticTexts["Sleep Analysis"].exists, "Sleep Analysis permission should be visible")
        XCTAssertTrue(app.staticTexts["Heart Rate Variability"].exists, "HRV permission should be visible")
        XCTAssertTrue(app.staticTexts["Steps"].exists, "Steps permission should be visible")
        XCTAssertTrue(app.staticTexts["Resting Heart Rate"].exists, "Resting Heart Rate permission should be visible")

        let manageButton = element(AccessibilityID.manageHealthPermissionsButton, in: app)
        XCTAssertTrue(manageButton.exists, "Manage Permissions button should be visible")
    }

    @MainActor
    func testSettingsAPIKeyTextFieldExists() {
        // APIKeyTextField is set in DiscoveryFeedView's settings sheet
        let app = launchApp()
        openSettings(app)

        let apiKeyField = element(AccessibilityID.apiKeyTextField, in: app)
        XCTAssertTrue(apiKeyField.exists, "API key text field should be visible in settings")
    }

    @MainActor
    func testSettingsViewCurrentHealthDataButtonExists() {
        // ViewCurrentHealthDataButton is set in DiscoveryFeedView's settings sheet
        let app = launchApp()
        openSettings(app)

        let button = element(AccessibilityID.viewCurrentHealthDataButton, in: app)
        XCTAssertTrue(button.exists, "View Current Health Data button should be visible in settings")
    }
}
