import XCTest

final class HealthKitPermissionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPermissionsViewAppearsWithCorrectLaunchArg() {
        let app = launchApp(showHealthKitPermissions: true)
        XCTAssertTrue(element(AccessibilityID.healthKitPermissionsView, in: app).waitForExistence(timeout: 5), "HealthKit permissions view should appear")
    }

    @MainActor
    func testGrantAccessButtonExists() {
        let app = launchApp(showHealthKitPermissions: true)
        XCTAssertTrue(element(AccessibilityID.healthKitPermissionsView, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(AccessibilityID.grantHealthKitAccessButton, in: app).exists, "Grant Access button should be visible")
    }
}
