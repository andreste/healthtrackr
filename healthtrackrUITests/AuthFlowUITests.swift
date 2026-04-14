import XCTest

final class AuthFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignInWithAppleButtonIsVisible() {
        let app = launchApp(skipAuth: false)
        XCTAssertTrue(element(AccessibilityID.signInView, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in with Apple"].waitForExistence(timeout: 5), "Sign in with Apple button should be visible")
    }

    @MainActor
    func testSignOutReturnsToSignInScreen() {
        let app = launchApp(skipAuth: true)
        XCTAssertTrue(app.navigationBars["Discoveries"].waitForExistence(timeout: 10))

        element(AccessibilityID.settingsButton, in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.collectionViews.firstMatch.swipeUp() // Scroll to Account section
        element(AccessibilityID.signOutButton, in: app).tap()

        XCTAssertTrue(element(AccessibilityID.signInView, in: app).waitForExistence(timeout: 5), "Sign-in screen should appear after sign out")
    }
}
