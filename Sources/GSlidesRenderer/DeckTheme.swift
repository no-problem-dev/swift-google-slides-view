import DesignSystem
import GSlidesSchema
import SwiftUI

extension RgbColor {
    var color: Color {
        Color(red: red ?? 0, green: green ?? 0, blue: blue ?? 0)
    }
}

/// Resolves the effective theme color scheme for a page, following the
/// slide → layout → master inheritance the Slides API defines.
public enum DeckTheme {
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

    /// The effective page background fill, following slide → layout inheritance.
    public static func backgroundFill(for page: Page, in presentation: Presentation) -> PageBackgroundFill? {
        page.pageProperties?.pageBackgroundFill ?? layoutBackground(for: page, in: presentation)
    }

    public static func backgroundColor(for page: Page, in presentation: Presentation, palette: DeckColorPalette) -> Color {
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

/// A DS `ColorPalette` synthesized from the deck's color scheme.
///
/// This is how "render with the deck's real theme" and "drive everything through the design
/// system" become the same thing: the deck's ACCENT1/TEXT1/BACKGROUND1 fill the DS semantic
/// slots (primary/onSurface/background…). Slide content and chrome then read one palette via
/// `@Environment(\.colorPalette)`. Slots the deck doesn't define fall back to `base`.
public struct DeckColorPalette: ColorPalette {
    let scheme: GSlidesSchema.ColorScheme?
    let base: any ColorPalette

    public init(scheme: GSlidesSchema.ColorScheme?, base: any ColorPalette = LightColorPalette()) {
        self.scheme = scheme
        self.base = base
    }

    /// The deck's RGB binding for a theme color, if the scheme defines it.
    public func themeColor(_ type: ThemeColorType) -> Color? {
        scheme?.rgb(for: type)?.color
    }

    /// Resolve a profile `OpaqueColor` to a concrete color: explicit RGB wins, theme colors
    /// resolve through the deck scheme, otherwise map onto this palette's semantic slot.
    public func resolve(_ opaque: OpaqueColor?) -> Color? {
        guard let opaque else { return nil }
        if let rgb = opaque.rgbColor { return rgb.color }
        guard let theme = opaque.themeColor else { return nil }
        return themeColor(theme) ?? semanticSlot(for: theme)
    }

    /// Fallback mapping when the deck scheme lacks a theme color: use the nearest DS slot.
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
