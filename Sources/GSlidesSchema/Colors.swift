/// RGB 色空間の色。Slides API の仕様に従い各成分は 0.0〜1.0 の浮動小数点数（0〜255 整数ではない）。
/// 未設定の成分は 0 として扱う。`google.apps.slides.v1.RgbColor` のミラー。
public struct RgbColor: Codable, Equatable, Sendable {
    public var red: Double?
    public var green: Double?
    public var blue: Double?

    public init(red: Double? = nil, green: Double? = nil, blue: Double? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#RRGGBB` または `RRGGBB` の hex 文字列から生成する。Slides API は各成分を「0.0〜1.0」の
    /// 浮動小数点で保持するため（discovery: `RgbColor.red/green/blue`）、各バイトを 255 で除算する。
    /// 6 桁の hex 以外の入力は nil を返す。
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// すべての設定済み成分が API 仕様の 0.0〜1.0 範囲内かどうか。
    /// 未設定の成分はチェックをパスする（フィールド省略可能なデコードモデルと一致）。
    public var componentsInRange: Bool {
        [red, green, blue].allSatisfy { $0.map { (0.0...1.0).contains($0) } ?? true }
    }
}

public struct ThemeColorType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "THEME_COLOR_TYPE_UNSPECIFIED")
    public static let dark1 = Self(rawValue: "DARK1")
    public static let light1 = Self(rawValue: "LIGHT1")
    public static let dark2 = Self(rawValue: "DARK2")
    public static let light2 = Self(rawValue: "LIGHT2")
    public static let accent1 = Self(rawValue: "ACCENT1")
    public static let accent2 = Self(rawValue: "ACCENT2")
    public static let accent3 = Self(rawValue: "ACCENT3")
    public static let accent4 = Self(rawValue: "ACCENT4")
    public static let accent5 = Self(rawValue: "ACCENT5")
    public static let accent6 = Self(rawValue: "ACCENT6")
    public static let hyperlink = Self(rawValue: "HYPERLINK")
    public static let followedHyperlink = Self(rawValue: "FOLLOWED_HYPERLINK")
    public static let text1 = Self(rawValue: "TEXT1")
    public static let background1 = Self(rawValue: "BACKGROUND1")
    public static let text2 = Self(rawValue: "TEXT2")
    public static let background2 = Self(rawValue: "BACKGROUND2")

    public static var knownValues: [Self] {
        [
            .unspecified, .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink, .text1, .background1, .text2, .background2,
        ]
    }

    /// API で編集可能な 12 の ThemeColorType — discovery enum 順。仕様上、設定できるのはこの 12 種のみ、
    /// `Master` ページ上のみ、かつカラースキーム更新時は 12 種すべてを提供しなければならない。
    /// 残り 4 種（TEXT1, BACKGROUND1, TEXT2, BACKGROUND2）は更新時に無視される。(catalog: theme-color-scheme-editable)
    public static var editableSlots: [Self] {
        [
            .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink,
        ]
    }

    /// このスロットの具体色が API で編集可能かどうか（先頭 12 種のうちの 1 つ）。
    public var isEditableSlot: Bool { Self.editableSlots.contains { $0.rawValue == rawValue } }
}

/// 明示的な RGB 値またはテーマカラースロットへの参照を持つ完全不透明色。
/// テーマカラーはレンダリング時にマスターの `ColorScheme` に束縛された具体 RGB に解決されるため、
/// マスター変更でデッキ全体が再描画される。`google.apps.slides.v1.OpaqueColor` のミラー。
public struct OpaqueColor: Codable, Equatable, Sendable {
    public var rgbColor: RgbColor?
    public var themeColor: ThemeColorType?

    public init(rgbColor: RgbColor? = nil, themeColor: ThemeColorType? = nil) {
        self.rgbColor = rgbColor
        self.themeColor = themeColor
    }
}

/// 存在しない場合がある色（透明 / no-op）。オプションの `OpaqueColor` をラップする。
/// Slides API で描画を明示的にクリアできる箇所で使用する。`google.apps.slides.v1.OptionalColor` のミラー。
public struct OptionalColor: Codable, Equatable, Sendable {
    public var opaqueColor: OpaqueColor?

    public init(opaqueColor: OpaqueColor? = nil) {
        self.opaqueColor = opaqueColor
    }
}

/// 不透明度を指定できる単色塗りつぶし。`alpha` は 0.0（透明）〜 1.0（完全不透明）。
/// `alpha` が省略された場合の Slides API デフォルトは 1.0。`google.apps.slides.v1.SolidFill` のミラー。
public struct SolidFill: Codable, Equatable, Sendable {
    public var color: OpaqueColor?
    public var alpha: Double?

    public init(color: OpaqueColor? = nil, alpha: Double? = nil) {
        self.color = color
        self.alpha = alpha
    }
}
