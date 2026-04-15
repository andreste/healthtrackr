import Foundation

/// Provides the correct bundle for localized string lookups across both
/// production and test targets.
///
/// In the app target `Bundle.main` is the app bundle and contains
/// `Localizable.xcstrings`. In unit test targets `Bundle.main` is the test
/// runner, which does *not* contain the strings file. Using
/// `Bundle(for: BundleLocator.self)` always resolves to the bundle that
/// contains this class — the app target — so lookups succeed in both contexts.
final class BundleLocator {}

extension Bundle {
    /// The bundle that contains `Localizable.xcstrings`.
    static let localization: Bundle = Bundle(for: BundleLocator.self)
}
