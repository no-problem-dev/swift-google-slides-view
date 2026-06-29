import DesignSystem
import GSlidesSchema
import SwiftUI

extension RgbColor {
    var color: Color {
        Color(red: red ?? 0, green: green ?? 0, blue: blue ?? 0)
    }
}

/// Slides API が定義する slide → layout → master 継承に従い、
/// ページの有効なテーマカラースキームを解決する。
public enum PresentationTheme {
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

    /// slide → layout 継承に従った有効なページ背景フィル。
    public static func backgroundFill(for page: Page, in presentation: Presentation) -> PageBackgroundFill? {
        page.pageProperties?.pageBackgroundFill ?? layoutBackground(for: page, in: presentation)
    }

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

/// プレゼンテーションのカラースキームから合成した DS `ColorPalette`。
///
/// 「プレゼンテーションの実際のテーマでレンダリングする」と「デザインシステムを通じて全てを駆動する」が
/// 同じことになる仕組み。プレゼンテーションの ACCENT1/TEXT1/BACKGROUND1 が DS のセマンティックスロット
/// （primary/onSurface/background…）を埋める。スライドコンテンツとクロームは
/// `@Environment(\.colorPalette)` 経由で 1 つのパレットを読む。プレゼンテーションが定義しないスロットは `base` にフォールバックする。
public struct PresentationColorPalette: ColorPalette {
    let scheme: GSlidesSchema.ColorScheme?
    let base: any ColorPalette

    public init(scheme: GSlidesSchema.ColorScheme?, base: any ColorPalette = LightColorPalette()) {
        self.scheme = scheme
        self.base = base
    }

    /// スキームが定義している場合、テーマカラーに対するプレゼンテーションの RGB バインディング。
    public func themeColor(_ type: ThemeColorType) -> Color? {
        scheme?.rgb(for: type)?.color
    }

    /// プロファイルの `OpaqueColor` を具体的なカラーに解決する。明示的な RGB が優先。
    /// テーマカラーはプレゼンテーションスキームを通じて解決し、それ以外はこのパレットのセマンティックスロットにマッピングする。
    public func resolve(_ opaque: OpaqueColor?) -> Color? {
        guard let opaque else { return nil }
        if let rgb = opaque.rgbColor { return rgb.color }
        guard let theme = opaque.themeColor else { return nil }
        return themeColor(theme) ?? semanticSlot(for: theme)
    }

    /// プレゼンテーションスキームにテーマカラーがない場合のフォールバックマッピング: 最も近い DS スロットを使用する。
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
