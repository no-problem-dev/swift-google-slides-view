import DesignSystem
import GSlidesSchema
import SwiftUI

/// Resolves the schema's color types to SwiftUI colors against a palette built from the presentation.
///
/// Theme colors resolve through the presentation's own scheme, so the deck keeps its intended
/// palette, and both slide content and surrounding chrome read from the same
/// `PresentationColorPalette`.
public struct GSlidesPalette: Sendable {
    public var presentation: PresentationColorPalette

    public init(presentation: PresentationColorPalette) {
        self.presentation = presentation
    }

    public init(scheme: GSlidesSchema.ColorScheme? = nil) {
        self.presentation = PresentationColorPalette(scheme: scheme)
    }

    public func color(_ opaque: OpaqueColor?) -> Color? {
        presentation.resolve(opaque)
    }

    public func color(_ optional: OptionalColor?) -> Color? {
        presentation.resolve(optional?.opaqueColor)
    }

    /// The fill's color with its alpha applied. A nil alpha means fully opaque.
    public func color(_ fill: SolidFill?) -> Color? {
        guard let fill else { return nil }
        return presentation.resolve(fill.color).map { $0.opacity(fill.alpha ?? 1) }
    }

    /// The color to draw text that carries no explicit foreground color.
    public var defaultText: Color { presentation.onSurface }
}

/// The fallback type scale for a placeholder that declares no font size of its own.
///
/// Sizes come from the design system's typography tokens so the renderer's defaults match it. An
/// explicit font size in the presentation always wins over these.
enum PlaceholderTypography {
    static func defaultFontSize(for type: PlaceholderType?, big: Bool = false) -> Double {
        let token: Typography = switch type {
        case .some(.centeredTitle): .displaySmall
        case .some(.title): big ? .displayLarge : .headlineMedium
        case .some(.subtitle): .titleMedium
        case .some(.body): .bodyLarge
        default: .bodyMedium
        }
        return Double(token.size)
    }

    static func weight(for type: PlaceholderType?) -> Font.Weight {
        switch type {
        case .some(.centeredTitle), .some(.title): .semibold
        default: .regular
        }
    }
}
