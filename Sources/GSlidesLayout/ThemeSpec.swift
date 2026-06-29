import GSlidesSchema

/// プレゼンテーションのデザイン意図を Slides API 固有の権威ある語彙で表現したもの: 12 の編集可能な
/// テーマカラースロット。API がセット可能なのはこのカラーのみで、`Master` ページにのみ設定でき、
/// 12 個をまとめて提供する必要がある（discovery: `PageProperties.colorScheme`、
/// catalog: theme-color-scheme-editable）。LLM は「白ベース」「ブルーアクセント」などの見た目の意図を
/// `ThemeSpec` として出力し、マスターの `ColorScheme` に無損失で焼き込む。
///
/// フィールド名は `ThemeColorType` と完全に一致させる — 独自の語彙は作らない。
/// Slides API にフォントスキーム（メジャー/マイナーテーマフォント）は存在しない。
/// タイポグラフィの意図は `TextStyle` ごとに適用するため、このカラースキーム仕様には含まない。
public struct ThemeSpec: Equatable, Sendable, Codable {
    // The 12 editable slots, in discovery enum order.
    public var dark1: RgbColor
    public var light1: RgbColor
    public var dark2: RgbColor
    public var light2: RgbColor
    public var accent1: RgbColor
    public var accent2: RgbColor
    public var accent3: RgbColor
    public var accent4: RgbColor
    public var accent5: RgbColor
    public var accent6: RgbColor
    public var hyperlink: RgbColor
    public var followedHyperlink: RgbColor

    public init(
        dark1: RgbColor, light1: RgbColor, dark2: RgbColor, light2: RgbColor,
        accent1: RgbColor, accent2: RgbColor, accent3: RgbColor, accent4: RgbColor,
        accent5: RgbColor, accent6: RgbColor, hyperlink: RgbColor, followedHyperlink: RgbColor
    ) {
        self.dark1 = dark1; self.light1 = light1; self.dark2 = dark2; self.light2 = light2
        self.accent1 = accent1; self.accent2 = accent2; self.accent3 = accent3
        self.accent4 = accent4; self.accent5 = accent5; self.accent6 = accent6
        self.hyperlink = hyperlink; self.followedHyperlink = followedHyperlink
    }

    /// 12 の編集可能スロットすべてをバインドした `ColorScheme`（例: `GSlidesThemeContract` で検証済みのもの）から構築する。
    /// 編集可能スロットのみを読み取り、4 つのエイリアスは `colorScheme` が再導出する。
    /// 編集可能スロットが 1 つでも未バインドの場合は nil を返す。
    public init?(colorScheme: ColorScheme) {
        func slot(_ type: ThemeColorType) -> RgbColor? { colorScheme.rgb(for: type) }
        guard let dark1 = slot(.dark1), let light1 = slot(.light1), let dark2 = slot(.dark2),
              let light2 = slot(.light2), let accent1 = slot(.accent1), let accent2 = slot(.accent2),
              let accent3 = slot(.accent3), let accent4 = slot(.accent4), let accent5 = slot(.accent5),
              let accent6 = slot(.accent6), let hyperlink = slot(.hyperlink),
              let followedHyperlink = slot(.followedHyperlink)
        else { return nil }
        self.init(
            dark1: dark1, light1: light1, dark2: dark2, light2: light2,
            accent1: accent1, accent2: accent2, accent3: accent3, accent4: accent4,
            accent5: accent5, accent6: accent6, hyperlink: hyperlink, followedHyperlink: followedHyperlink)
    }

    /// 編集可能スロットごとにバインドされた RGB（enum 順）。シンセサイザーと準拠チェックが読む唯一の情報源。
    public var editableColors: [(ThemeColorType, RgbColor)] {
        [
            (.dark1, dark1), (.light1, light1), (.dark2, dark2), (.light2, light2),
            (.accent1, accent1), (.accent2, accent2), (.accent3, accent3),
            (.accent4, accent4), (.accent5, accent5), (.accent6, accent6),
            (.hyperlink, hyperlink), (.followedHyperlink, followedHyperlink),
        ]
    }

    /// 実際の `presentations.get` マスターが持つ 16 エントリの完全な `ColorScheme`。
    /// 12 の編集可能スロットをそのまま含み、API が導出する 4 つの読み取り専用エイリアスを追加する。
    /// TEXT1←DARK1、BACKGROUND1←LIGHT1、TEXT2←DARK2、BACKGROUND2←LIGHT2
    /// （慣例的なテキスト-背景マッピング。API は更新時にこれらを無視する）。順序は discovery enum に一致。
    public var colorScheme: ColorScheme {
        ColorScheme(colors: editableColors.map { ThemeColorPair(type: $0.0, color: $0.1) } + [
            ThemeColorPair(type: .text1, color: dark1),
            ThemeColorPair(type: .background1, color: light1),
            ThemeColorPair(type: .text2, color: dark2),
            ThemeColorPair(type: .background2, color: light2),
        ])
    }
}

public extension ThemeSpec {
    /// クリーンでプロフェッショナルなライトテーマ（白キャンバス、ダークテキスト、ティールのプライマリアクセント）。
    /// パッケージのデフォルト。従来の組み込みライトスキームと同一の RGB 値。
    static let light = ThemeSpec(
        dark1: RgbColor(red: 0.11, green: 0.13, blue: 0.16),    // primary text / on-canvas
        light1: RgbColor(red: 1, green: 1, blue: 1),            // canvas
        dark2: RgbColor(red: 0.42, green: 0.46, blue: 0.51),    // muted captions
        light2: RgbColor(red: 0.93, green: 0.94, blue: 0.96),   // tinted surface
        accent1: RgbColor(red: 0.0, green: 0.47, blue: 0.56),
        accent2: RgbColor(red: 0.91, green: 0.45, blue: 0.23),
        accent3: RgbColor(red: 0.18, green: 0.62, blue: 0.42),
        accent4: RgbColor(red: 0.88, green: 0.66, blue: 0.18),
        accent5: RgbColor(red: 0.42, green: 0.36, blue: 0.65),
        accent6: RgbColor(red: 0.78, green: 0.29, blue: 0.49),
        hyperlink: RgbColor(red: 0.10, green: 0.45, blue: 0.91),
        followedHyperlink: RgbColor(red: 0.42, green: 0.25, blue: 0.63))

    /// ダークテーマ: 限りなく黒に近いキャンバス、ライトテキスト、コントラストを高めた明るいアクセント。
    static let dark = ThemeSpec(
        dark1: RgbColor(red: 0.92, green: 0.94, blue: 0.96),
        light1: RgbColor(red: 0.07, green: 0.08, blue: 0.10),
        dark2: RgbColor(red: 0.64, green: 0.68, blue: 0.73),
        light2: RgbColor(red: 0.16, green: 0.18, blue: 0.21),
        accent1: RgbColor(red: 0.33, green: 0.80, blue: 0.88),
        accent2: RgbColor(red: 1.0, green: 0.60, blue: 0.42),
        accent3: RgbColor(red: 0.37, green: 0.83, blue: 0.61),
        accent4: RgbColor(red: 0.95, green: 0.81, blue: 0.42),
        accent5: RgbColor(red: 0.66, green: 0.61, blue: 0.88),
        accent6: RgbColor(red: 0.91, green: 0.52, blue: 0.69),
        hyperlink: RgbColor(red: 0.44, green: 0.66, blue: 1.0),
        followedHyperlink: RgbColor(red: 0.72, green: 0.61, blue: 0.88))
}
