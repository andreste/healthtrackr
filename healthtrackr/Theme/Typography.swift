import SwiftUI

enum Typography {
    // MARK: - Font Names
    private static let fraunces = "Fraunces"
    private static let instrumentSans = "InstrumentSans-Regular"
    private static let geistMono = "GeistMono-Regular"
    private static let geistMonoMedium = "GeistMono-Medium"

    // MARK: - Display (Fraunces)

    static let displayXL = Font.custom(fraunces, size: 42, relativeTo: .largeTitle)
    static let displayLG = Font.custom(fraunces, size: 28, relativeTo: .title)
    static let displayMD = Font.custom(fraunces, size: 22, relativeTo: .title2)
    static let displaySM = Font.custom(fraunces, size: 18, relativeTo: .title3)
    static let displayItalic = Font.custom(fraunces, size: 16, relativeTo: .subheadline).italic()

    // MARK: - Body (Instrument Sans)

    static let bodyLG = Font.custom(instrumentSans, size: 16, relativeTo: .body)
    static let bodyMD = Font.custom(instrumentSans, size: 14, relativeTo: .body)
    static let bodySM = Font.custom(instrumentSans, size: 13, relativeTo: .footnote)
    static let labelMD = Font.custom(instrumentSans, size: 13, relativeTo: .caption).weight(.semibold)
    static let labelSM = Font.custom(instrumentSans, size: 11, relativeTo: .caption2).weight(.semibold)

    // MARK: - Data (Geist Mono)

    static let dataLG = Font.custom(geistMonoMedium, size: 28, relativeTo: .largeTitle)
    static let dataMD = Font.custom(geistMono, size: 18, relativeTo: .body)
    static let dataSM = Font.custom(geistMono, size: 12, relativeTo: .caption)
    static let dataXS = Font.custom(geistMono, size: 10, relativeTo: .caption2)

    // MARK: - Line Heights

    enum LineHeight {
        static let displayXL: CGFloat = 42 * 1.1
        static let displayLG: CGFloat = 28 * 1.2
        static let displayMD: CGFloat = 22 * 1.25
        static let displaySM: CGFloat = 18 * 1.3
        static let displayItalic: CGFloat = 16 * 1.35
        static let bodyLG: CGFloat = 16 * 1.6
        static let bodyMD: CGFloat = 14 * 1.55
        static let bodySM: CGFloat = 13 * 1.5
        static let labelMD: CGFloat = 13 * 1.4
        static let labelSM: CGFloat = 11 * 1.3
        static let dataLG: CGFloat = 28 * 1.1
        static let dataMD: CGFloat = 18 * 1.2
        static let dataSM: CGFloat = 12 * 1.4
        static let dataXS: CGFloat = 10 * 1.3
    }

    // MARK: - Letter Spacing

    enum Tracking {
        static let display: CGFloat = -0.02
        static let body: CGFloat = 0
        static let monoDefault: CGFloat = 0
        static let monoCaps: CGFloat = 0.05
    }
}
