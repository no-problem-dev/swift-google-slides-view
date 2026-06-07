import GSlidesSchema
import SwiftUI

/// Resolves profile colors to SwiftUI colors. Theme colors map onto a small
/// default palette that callers can replace.
public struct GSlidesPalette: Sendable {
    public var theme: [ThemeColorType: Color]

    public init(theme: [ThemeColorType: Color] = Self.defaultTheme) {
        self.theme = theme
    }

    public static let defaultTheme: [ThemeColorType: Color] = [
        .dark1: Color(red: 0.13, green: 0.13, blue: 0.13),
        .light1: .white,
        .dark2: Color(red: 0.26, green: 0.26, blue: 0.26),
        .light2: Color(red: 0.95, green: 0.95, blue: 0.95),
        .accent1: Color(red: 0.26, green: 0.52, blue: 0.96),
        .accent2: Color(red: 0.92, green: 0.26, blue: 0.21),
        .accent3: Color(red: 0.98, green: 0.74, blue: 0.02),
        .accent4: Color(red: 0.20, green: 0.66, blue: 0.33),
        .accent5: Color(red: 1.00, green: 0.43, blue: 0.00),
        .accent6: Color(red: 0.27, green: 0.78, blue: 0.84),
        .text1: Color(red: 0.13, green: 0.13, blue: 0.13),
        .background1: .white,
    ]

    public func color(_ opaque: OpaqueColor?) -> Color? {
        guard let opaque else { return nil }
        if let rgb = opaque.rgbColor {
            return Color(red: rgb.red ?? 0, green: rgb.green ?? 0, blue: rgb.blue ?? 0)
        }
        if let theme = opaque.themeColor {
            return self.theme[theme]
        }
        return nil
    }

    public func color(_ optional: OptionalColor?) -> Color? {
        color(optional?.opaqueColor)
    }

    public func color(_ fill: SolidFill?) -> Color? {
        guard let fill else { return nil }
        return color(fill.color).map { $0.opacity(fill.alpha ?? 1) }
    }
}

/// Default typography for placeholder types when content carries no explicit
/// font size — point sizes chosen to match Google Slides' default theme scale.
enum PlaceholderTypography {
    static func defaultFontSize(for type: PlaceholderType?, big: Bool = false) -> Double {
        switch type {
        case .some(.centeredTitle): 40
        case .some(.title): big ? 64 : 34
        case .some(.subtitle): 22
        case .some(.body): 16
        default: 14
        }
    }
}
