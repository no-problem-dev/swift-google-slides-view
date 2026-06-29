import DesignSystem
import GSlidesSchema
import SwiftUI

/// プロファイルカラーをプレゼンテーション由来の DS パレットに対して SwiftUI カラーに解決する。
/// テーマカラーはプレゼンテーションのスキームを通じて解決し（忠実度を保つ）、
/// クロームが使う `PresentationColorPalette` と同一のパレット上で全てを表現する。
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

    /// プレゼンテーションのデフォルトの on-surface テキストカラー。
    public var defaultText: Color { presentation.onSurface }
}

/// プレースホルダータイプのデフォルトタイポグラフィ。DS Typography トークン（ポイントサイズ）から取得し、
/// レンダラーのデフォルトスケールをデザインシステムと一致させる。明示的なプレゼンテーションフォントサイズが優先される。
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
