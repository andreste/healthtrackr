import XCTest

extension XCTestCase {
    func launchApp(
        skipAuth: Bool = true,
        stubEmptyFeed: Bool = false,
        healthKitDenied: Bool = false,
        showHealthKitPermissions: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        if skipAuth { app.launchArguments.append("--skip-auth") }
        if stubEmptyFeed { app.launchArguments.append("--stub-empty-feed") }
        if healthKitDenied { app.launchArguments.append("--healthkit-denied") }
        if showHealthKitPermissions { app.launchArguments.append("--show-healthkit-permissions") }
        app.launch()
        return app
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waitFor(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 10) -> XCUIElement {
        let el = element(identifier, in: app)
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected element '\(identifier)' to exist within \(timeout)s")
        return el
    }
}

enum AccessibilityID {
    static let signInView = "SignInView"
    static let discoveryFeedView = "DiscoveryFeedView"
    static let patternDetailView = "PatternDetailView"
    static let healthKitPermissionsView = "HealthKitPermissionsView"
    static let grantHealthKitAccessButton = "GrantHealthKitAccessButton"
    static let settingsButton = "SettingsButton"
    static let signOutButton = "SignOutButton"
    static let manageHealthPermissionsButton = "ManageHealthPermissionsButton"
    static let viewCurrentHealthDataButton = "ViewCurrentHealthDataButton"
    static let apiKeyTextField = "APIKeyTextField"
    static func patternCard(_ pairId: String) -> String { "PatternCard_\(pairId)" }
    static func filterChip(_ label: String) -> String { "FilterChip_\(label)" }
}
