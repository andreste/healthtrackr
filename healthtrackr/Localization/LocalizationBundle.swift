import Foundation

enum BundleLocator {
    private final class _Anchor {}
    static let bundle: Bundle = Bundle(for: _Anchor.self)
}

extension Bundle {
    static let localization: Bundle = BundleLocator.bundle
}
