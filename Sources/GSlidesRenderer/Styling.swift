import DesignSystem
import GSlidesSchema
import SwiftUI

/// Resolves profile colors to SwiftUI colors against a deck-derived DS palette.
/// Theme colors resolve through the deck's scheme (fidelity); everything is expressed
/// on the same `DeckColorPalette` the chrome uses.
public struct GSlidesPalette: Sendable {
    public var deck: DeckColorPalette

    public init(deck: DeckColorPalette) {
        self.deck = deck
    }

    public init(scheme: GSlidesSchema.ColorScheme? = nil) {
        self.deck = DeckColorPalette(scheme: scheme)
    }

    public func color(_ opaque: OpaqueColor?) -> Color? {
        deck.resolve(opaque)
    }

    public func color(_ optional: OptionalColor?) -> Color? {
        deck.resolve(optional?.opaqueColor)
    }

    public func color(_ fill: SolidFill?) -> Color? {
        guard let fill else { return nil }
        return deck.resolve(fill.color).map { $0.opacity(fill.alpha ?? 1) }
    }

    /// Default on-surface text color for the deck.
    public var defaultText: Color { deck.onSurface }
}

/// Default typography for placeholder types — sourced from DS Typography tokens (point sizes)
/// so the renderer's default scale matches the design system. Explicit deck font sizes win.
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
