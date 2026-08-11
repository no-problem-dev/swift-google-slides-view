import DesignSystem
import GSlidesSchema
import SwiftUI

extension RgbColor {
    var color: Color {
        Color(red: red ?? 0, green: green ?? 0, blue: blue ?? 0)
    }
}

/// Walks the slide → layout → master inheritance the Slides API defines to find what a page
/// actually renders with.
public enum PresentationTheme {
    /// The effective color scheme for a page.
    ///
    /// Tries the page's own scheme, then its layout's, then its master's, and finally the first
    /// master in the deck — that last step covers slides that omit their master reference, which is
    /// common in generated decks. An empty scheme is treated as absent, not as an override.
    ///
    /// - Returns: nil when nothing in the chain defines one, leaving the caller on design-system
    ///   defaults.
    public static func colorScheme(for page: Page, in presentation: Presentation) -> GSlidesSchema.ColorScheme? {
        if let own = page.pageProperties?.colorScheme, own.colors?.isEmpty == false { return own }
        if let layoutId = page.slideProperties?.layoutObjectId,
           let layout = presentation.layouts?.first(where: { $0.objectId == layoutId }),
           let scheme = layout.pageProperties?.colorScheme, scheme.colors?.isEmpty == false {
            return scheme
        }
        if let masterId = page.slideProperties?.masterObjectId,
           let master = presentation.masters?.first(where: { $0.objectId == masterId }),
           let scheme = master.pageProperties?.colorScheme {
            return scheme
        }
        // Fall back to the first master's scheme (common when slides omit the master ref).
        return presentation.masters?.first?.pageProperties?.colorScheme
    }

    /// The effective page background fill, from the page itself or its layout.
    ///
    /// Stops at the layout — unlike the color scheme, the master is not consulted.
    public static func backgroundFill(for page: Page, in presentation: Presentation) -> PageBackgroundFill? {
        page.pageProperties?.pageBackgroundFill ?? layoutBackground(for: page, in: presentation)
    }

    /// The page's solid background color, falling back to the palette's background.
    ///
    /// Covers solid fills only. A stretched-picture background resolves to the fallback color here;
    /// draw the picture separately.
    public static func backgroundColor(for page: Page, in presentation: Presentation, palette: PresentationColorPalette) -> Color {
        let fill = backgroundFill(for: page, in: presentation)
        if let solid = fill?.solidFill, let color = palette.resolve(solid.color) {
            return color.opacity(solid.alpha ?? 1)
        }
        return palette.background
    }

    private static func layoutBackground(for page: Page, in presentation: Presentation) -> PageBackgroundFill? {
        guard let layoutId = page.slideProperties?.layoutObjectId,
              let layout = presentation.layouts?.first(where: { $0.objectId == layoutId })
        else { return nil }
        return layout.pageProperties?.pageBackgroundFill
    }
}

/// A design-system `ColorPalette` synthesized from a presentation's color scheme.
///
/// This is what makes "render in the deck's real theme" and "drive everything through the design
/// system" the same thing: the deck's ACCENT1, TEXT1 and BACKGROUND1 fill the design system's
/// semantic slots, and slide content and chrome both read one palette from
/// `@Environment(\.colorPalette)`.
///
/// Slots the presentation does not define fall through to `base`, so a partially themed deck mixes
/// its own colors with the app's — set `base` to control what it mixes with.
public struct PresentationColorPalette: ColorPalette {
    let scheme: GSlidesSchema.ColorScheme?
    let base: any ColorPalette

    public init(scheme: GSlidesSchema.ColorScheme?, base: any ColorPalette = LightColorPalette()) {
        self.scheme = scheme
        self.base = base
    }

    /// The RGB this presentation binds to a theme color, or nil when its scheme leaves it unbound.
    public func themeColor(_ type: ThemeColorType) -> Color? {
        scheme?.rgb(for: type)?.color
    }

    /// Resolves an `OpaqueColor` to a concrete color.
    ///
    /// An explicit RGB wins. A theme color resolves through the presentation's scheme, and falls
    /// back to the nearest semantic slot of this palette when the scheme does not bind it.
    ///
    /// - Returns: nil for a nil color, and for one that sets neither an RGB nor a theme color.
    public func resolve(_ opaque: OpaqueColor?) -> Color? {
        guard let opaque else { return nil }
        if let rgb = opaque.rgbColor { return rgb.color }
        guard let theme = opaque.themeColor else { return nil }
        return themeColor(theme) ?? semanticSlot(for: theme)
    }

    /// Maps a theme color the presentation does not bind onto the closest design-system slot.
    ///
    /// Total, so an unbound accent still draws something; unmapped types land on `onSurfaceVariant`.
    private func semanticSlot(for theme: ThemeColorType) -> Color {
        switch theme {
        case .accent1: primary
        case .accent2: secondary
        case .accent3: tertiary
        case .dark1, .text1: onBackground
        case .light1, .background1: background
        case .light2, .background2: surfaceVariant
        case .hyperlink: info
        default: onSurfaceVariant
        }
    }

    private func slot(_ type: ThemeColorType, _ fallback: Color) -> Color {
        themeColor(type) ?? fallback
    }

    // Core slots (the rest get DS default implementations).
    public var primary: Color { slot(.accent1, base.primary) }
    public var secondary: Color { slot(.accent2, base.secondary) }
    public var tertiary: Color { slot(.accent3, base.tertiary) }
    public var background: Color { themeColor(.background1) ?? themeColor(.light1) ?? base.background }
    public var onBackground: Color { themeColor(.text1) ?? themeColor(.dark1) ?? base.onBackground }
    public var surface: Color { themeColor(.background1) ?? themeColor(.light1) ?? base.surface }
    public var onSurface: Color { themeColor(.text1) ?? themeColor(.dark1) ?? base.onSurface }
    public var surfaceVariant: Color { themeColor(.light2) ?? base.surfaceVariant }
    public var onSurfaceVariant: Color { themeColor(.dark2) ?? base.onSurfaceVariant }
    public var error: Color { base.error }
    public var warning: Color { base.warning }
    public var success: Color { base.success }
    public var info: Color { themeColor(.hyperlink) ?? base.info }
    public var outline: Color { themeColor(.dark2) ?? base.outline }
}
