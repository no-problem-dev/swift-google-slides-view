import GSlidesSchema

/// スライドジオメトリのデザインシステム層。垂直リズムスケールと有限のヘッダー処理セットを持つ。
/// `ThemeSpec`（カラー）と `PresentationTypography`（フォント）が各ドメインで実現しているのと同じ考え方で、
/// *デザイン*を交換可能なトークン/バリアントとして表現し、レイアウトごとのジオメトリに散在するマジックナンバーを避ける。
/// 一貫性は構造的に強制される。コンテンツスライドのヘッダーとボディは 1 つのスケールを共有するため、
/// レイアウト間でズレが生じない。
///
/// この層は Google Slides ワイヤースキーマ（`GSlidesSchema`）の*上*に位置し、
/// 常にスキーマ準拠の構造を出力する。アイブロウ/ヘッドラインヘッダーは 2 つのスタイル付きパラグラフを持つ
/// 単一の `TITLE` プレースホルダー（Slides ネイティブのテキストモデル）+ アクセント用の `ThemeColorType` ロールで、
/// 独自要素は使わない。生成したデッキは実際の Slides API にそのまま round-trip できる。
public struct SpacingScale: Sendable, Equatable {
    // EMU on the standard 16:9 page (PresentationTemplate.pageW/H).

    /// タイトルボックスの上端（ページコンテンツマージン）。
    public var headerTop: Double
    /// タイトルボックスの高さ。アイブロウ + ヘッドラインの段落を上端揃えで収める。
    public var headerHeight: Double
    /// タイトルボックスからボディ領域までのギャップ。
    public var headlineToBody: Double

    /// アイブロウ（カテゴリキッカー）のポイントサイズ。ヘッドラインより小さい。
    public var eyebrowFontPt: Double
    /// アイブロウパラグラフの下のスペース（アイブロウ → ヘッドライン間のギャップ）、ポイント単位。
    public var eyebrowGapPt: Double

    /// ヘッダー下のコンテンツボディ領域の高さ。
    public var bodyHeight: Double
    /// 横並びカラム間のギャップ（2 カラムレイアウト、並列比較の区切り）。
    public var columnGap: Double
    /// フッターバンド: ページ下端からのボックスインセット、およびフッターボックスの高さ。
    public var footerBottomInset: Double
    public var footerHeight: Double

    public init(
        headerTop: Double,
        headerHeight: Double,
        headlineToBody: Double,
        eyebrowFontPt: Double,
        eyebrowGapPt: Double,
        bodyHeight: Double,
        columnGap: Double,
        footerBottomInset: Double,
        footerHeight: Double
    ) {
        self.headerTop = headerTop
        self.headerHeight = headerHeight
        self.headlineToBody = headlineToBody
        self.eyebrowFontPt = eyebrowFontPt
        self.eyebrowGapPt = eyebrowGapPt
        self.bodyHeight = bodyHeight
        self.columnGap = columnGap
        self.footerBottomInset = footerBottomInset
        self.footerHeight = footerHeight
    }

    /// コンテンツスライドのボディ領域が始まる y 座標。ヘッダーから導出し、手動配置しない。
    /// ヘッダーとボディが同一の真実源を共有し、リズムが保たれる。
    public var bodyTop: Double { headerTop + headerHeight + headlineToBody }

    /// デフォルトのコンテンツスライドリズム。
    public static let content = SpacingScale(
        headerTop: 685_800,        // page margin (0.75")
        headerHeight: 840_000,
        headlineToBody: 180_000,
        eyebrowFontPt: 13,
        eyebrowGapPt: 3,
        bodyHeight: 2_950_000,
        columnGap: 400_000,
        footerBottomInset: 520_000,
        footerHeight: 300_000
    )
}

/// コンテンツスライドのヘッダー（タイトルゾーン）の構成方法。有限のセット — 生成とレンダリングは
/// バリアントを*選択*するだけで、ジオメトリを新たに作らない。新しい見た目はケースとして追加し、
/// マジックナンバーを追加しない。これによりシステムが交換可能かつ一貫性を保つ。
public enum HeaderStyle: Sendable, Equatable {
    /// ヘッドラインの上に小さなアクセントカラーのカテゴリキッカーを置く構成。タイトルプレースホルダー内の
    /// 2 つのパラグラフで実現する。「ラベル：結論」タイトルと組み合わせ、ラベルがアイブロウに、結論がヘッドラインになる。
    /// アクセントはアイブロウのカラーとして表現 — 独立したフローティングルールは使わない。
    case eyebrowHeadline
    /// アイブロウなしの単一ヘッドライン（従来のシングルラインタイトル）。アクセントはデコレーションが処理する。
    case plain
}

/// デッキのジオメトリ + ヘッダー処理に対するデザインシステム入力の全体。カラー（`ThemeSpec`）と
/// タイポグラフィ（`PresentationTypography`）を供給するのと同じ方法でプロファイルやテーマが提供できるよう
/// まとめる。テンプレート/エクスパンダーはこれを*受け取り*、それに従って配置する。ジオメトリを発明しないため、
/// スケールやヘッダーバリアントを交換するだけで全コンテンツスライドが一括で再スキンされる。
/// 一貫性不変条件（1 スケール → ヘッダーとボディがズレない）は構造的に保証される。
public struct SlideDesignSystem: Sendable, Equatable {
    /// 垂直リズムトークン。よりコンパクト/ゆとりのあるデッキに交換できる。
    public var scale: SpacingScale
    /// コンテンツスライドヘッダーの構成方法。異なるタイトル処理に交換できる。
    public var headerStyle: HeaderStyle

    public init(scale: SpacingScale = .content, headerStyle: HeaderStyle = .eyebrowHeadline) {
        self.scale = scale
        self.headerStyle = headerStyle
    }

    /// デフォルトのコンテンツスライドデザインシステム: 標準リズム + アイブロウ/ヘッドラインヘッダー。
    public static let standard = SlideDesignSystem()
}
