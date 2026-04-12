import Testing
import UIKit
@testable import healthtrackr

@Suite("HealthPermissionItem")
struct HealthPermissionItemTests {

    @Test("all items have non-empty ids, icons, and labels")
    func allItemsHaveRequiredFields() {
        for item in HealthPermissionItem.all {
            #expect(!item.id.isEmpty, "id should not be empty for item: \(item.label)")
            #expect(!item.icon.isEmpty, "icon should not be empty for item: \(item.label)")
            #expect(!item.label.isEmpty, "label should not be empty for item: \(item.label)")
        }
    }

    @Test("all SF Symbol names are valid system symbols")
    func allIconsAreValidSFSymbols() {
        for item in HealthPermissionItem.all {
            let image = UIImage(systemName: item.icon)
            #expect(image != nil, "'\(item.icon)' is not a valid SF Symbol (used for '\(item.label)')")
        }
    }

    @Test("blood oxygen uses drop.circle.fill symbol")
    func bloodOxygenUsesDropCircleFill() {
        let bloodOxygen = HealthPermissionItem.all.first { $0.id == "bloodOxygen" }
        #expect(bloodOxygen != nil, "bloodOxygen permission item should exist")
        #expect(bloodOxygen?.icon == "drop.circle.fill")
    }

    @Test("blood oxygen symbol is a valid SF Symbol")
    func bloodOxygenSymbolIsValid() {
        let bloodOxygen = HealthPermissionItem.all.first { $0.id == "bloodOxygen" }
        guard let icon = bloodOxygen?.icon else {
            Issue.record("bloodOxygen permission item not found")
            return
        }
        let image = UIImage(systemName: icon)
        #expect(image != nil, "'\(icon)' must be a valid SF Symbol")
    }
}
