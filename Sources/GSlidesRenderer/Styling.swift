import DesignSystem
import GSlidesSchema
import SwiftUI

/// Resolves profile colors to SwiftUI colors against a presentation-derived DS palette.
/// Theme colors resolve through the presentation's scheme (fidelity); everything is expressed
/// on the same `PresentationColorPalette` the chrome uses.
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

    public func color(_ fill: SolidFill?) -> Color? {
        guard let fill else { return nil }
        return presentation.resolve(fill.color).map { $0.opacity(fill.alpha ?? 1) }
    }

    /// Default on-surface text color for the presentation.
    public var defaultText: Color { presentation.onSurface }
}

/// Default typography for placeholder types — sourced from DS Typography tokens (point sizes)
/// so the renderer's default scale matches the design system. Explicit presentation font sizes win.
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
