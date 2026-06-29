import GSlidesSchema

/// レイアウトのスロット 1 つ分のプレースホルダージオメトリとデフォルトテキストスタイル。
/// 実際の Google Slides レイアウトページが持つ形式（EMU rect + スタイル）でデータとして表現する。
public struct PlaceholderSpec: Sendable {
    public var x, y, w, h: Double          // 標準 16:9 ページ上の EMU 座標
    public var fontSizePt: Double
    public var themeColor: ThemeColorType
    public var bold: Bool
    public var align: Alignment            // 水平テキスト配置
    public var vAlign: ContentAlignment    // ボックス内の垂直配置
    /// タイポグラフィの意図（Slides `TextStyle.fontFamily` / `weightedFontFamily`）。両方 nil の場合、
    /// レンダラーはシステムフォント + プレースホルダーのデフォルトウェイトを使う（従来の挙動）。
    public var fontFamily: String?         // 例: "Hiragino Sans" — ランのフォントファミリーとして適用
    public var weight: Int?                // 数値フォントウェイト 100–900（bold フラグより細かい指定）

    public init(
        x: Double, y: Double, w: Double, h: Double,
        fontSizePt: Double, themeColor: ThemeColorType, bold: Bool,
        align: Alignment, vAlign: ContentAlignment,
        fontFamily: String? = nil, weight: Int? = nil
    ) {
        self.x = x; self.y = y; self.w = w; self.h = h
        self.fontSizePt = fontSizePt; self.themeColor = themeColor; self.bold = bold
        self.align = align; self.vAlign = vAlign
        self.fontFamily = fontFamily; self.weight = weight
    }

    public var size: Size {
        Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu))
    }
    public var transform: AffineTransform {
        AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu)
    }
    public var defaultStyle: TextStyle {
        TextStyle(
            bold: bold,
            fontFamily: fontFamily,
            fontSize: Dimension(magnitude: fontSizePt, unit: .pt),
            foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: themeColor)),
            weightedFontFamily: (fontFamily != nil || weight != nil)
                ? WeightedFontFamily(fontFamily: fontFamily, weight: weight)
                : nil
        )
    }
}

/// プレゼンテーションのデザインをデータとして表現する。マスターテーマ（ColorScheme）と、各定義済みレイアウトの
/// プレースホルダー矩形・デフォルトスタイルを保持する。「見た目」はプロトコル固有の語彙（layout/master ページ）で
/// 表現され、レンダラーコードに埋め込まない。実際の `presentations.get` も同じデータを持つ。
/// LLM 生成プレゼンテーションは `PresentationExpander` 経由でこれを借用し、同一のジオメトリパスでレンダリングする。
public enum PresentationTemplate {
    // Standard 16:9 page (EMU) and a comfortable margin.
    static let pageW: Double = 9_144_000
    static let pageH: Double = 5_143_500
    static let margin: Double = 685_800          // 0.75"
    static var contentW: Double { pageW - 2 * margin }

    public static let masterObjectId = "gslides-master"

    /// 任意のデザイン意図のカラースキームを持つマスターページ。`ThemeSpec`（編集可能な 12 スロット）を
    /// マスターの `ColorScheme` に焼き込む。各プレースホルダー/デコレーションはそのスロットを
    /// シンボリックに参照（`.text1`/`.dark2`/`.accent1`）するため、デッキ全体が自動的に再配色される。
    public static func master(theme: ThemeSpec, displayName: String = "GSlides Theme") -> Page {
        Page(
            objectId: masterObjectId,
            pageType: .master,
            pageProperties: PageProperties(colorScheme: theme.colorScheme),
            masterProperties: MasterProperties(displayName: displayName)
        )
    }


    /// スロットのプレースホルダー spec。このレイアウトが定義していなければ nil を返す（レンダラーは
    /// セマンティックスタックレイアウトにフォールバックする）。`typography` スケールはスロットの
    /// セマンティックロールに応じてフォントファミリー + ウェイトをジオメトリに重ねる（nil 埋めのみ。
    /// 既にタイポグラフィが固定されているスロットはそのまま保持）。`.system` は従来のシステムフォントデフォルト。
    public static func spec(
        layout: PredefinedLayout,
        type: PlaceholderType,
        index: Int,
        typography: PresentationTypography = .system,
        scale: SpacingScale = .content
    ) -> PlaceholderSpec? {
        guard var spec = baseSpec(layout: layout, type: type, index: index, scale: scale) else { return nil }
        let style = typography.style(for: typographicRole(layout: layout, type: type))
        if spec.fontFamily == nil { spec.fontFamily = style.fontFamily }
        if spec.weight == nil { spec.weight = style.weight }
        return spec
    }

    /// スロットが対応するセマンティックタイポグラフィロール。プレースホルダーが
    /// `PresentationTypography` からファミリー/ウェイトを取得する際の参照先を決定する。
    /// カラーは直交（テーマが管理する）。
    static func typographicRole(layout: PredefinedLayout, type: PlaceholderType) -> PresentationTypography.Role {
        switch type {
        case .centeredTitle, .title:
            return layout == .bigNumber ? .bigNumber : .title
        case .subtitle:
            return .subtitle
        default:
            return .body
        }
    }

    /// スロットのプレースホルダージオメトリとデフォルト（タイポグラフィ以外の）スタイル。
    /// データとしてのレイアウトデザイン。`spec(...)` がこの上にタイポグラフィスケールを重ねる。
    private static func baseSpec(layout: PredefinedLayout, type: PlaceholderType, index: Int, scale: SpacingScale = .content) -> PlaceholderSpec? {
        let M = margin, cW = contentW
        switch (layout, type) {
        case (.title, .centeredTitle), (.title, .title):
            return PlaceholderSpec(x: M, y: 1_750_000, w: cW, h: 1_000_000, fontSizePt: 40, themeColor: .text1, bold: true, align: .center, vAlign: .middle)
        case (.title, .subtitle):
            return PlaceholderSpec(x: M, y: 2_820_000, w: cW, h: 600_000, fontSizePt: 20, themeColor: .dark2, bold: false, align: .center, vAlign: .top)

        case (.sectionHeader, _), (.sectionTitleAndDescription, .title):
            return PlaceholderSpec(x: M, y: 1_950_000, w: cW, h: 1_150_000, fontSizePt: 36, themeColor: .text1, bold: true, align: .start, vAlign: .middle)
        case (.sectionTitleAndDescription, .subtitle), (.sectionTitleAndDescription, .body):
            return PlaceholderSpec(x: M, y: 3_150_000, w: cW, h: 900_000, fontSizePt: 18, themeColor: .dark2, bold: false, align: .start, vAlign: .top)

        case (.bigNumber, .title), (.bigNumber, .centeredTitle):
            return PlaceholderSpec(x: M, y: 1_350_000, w: cW, h: 1_550_000, fontSizePt: 110, themeColor: .accent1, bold: true, align: .start, vAlign: .middle)
        case (.bigNumber, .body):
            return PlaceholderSpec(x: M, y: 3_050_000, w: cW, h: 900_000, fontSizePt: 22, themeColor: .text1, bold: false, align: .start, vAlign: .top)

        case (.mainPoint, .title), (.mainPoint, .centeredTitle):
            return PlaceholderSpec(x: M, y: 1_650_000, w: cW, h: 1_350_000, fontSizePt: 40, themeColor: .text1, bold: true, align: .start, vAlign: .middle)
        case (.mainPoint, .body):
            return PlaceholderSpec(x: M, y: 3_150_000, w: cW, h: 700_000, fontSizePt: 20, themeColor: .dark2, bold: false, align: .start, vAlign: .top)

        case (.titleAndTwoColumns, .title):
            return contentHeadlineSpec(scale: scale)
        case (.titleAndTwoColumns, .body):
            let s = scale
            let colW = (cW - s.columnGap) / 2
            let x = index == 0 ? M : M + colW + s.columnGap
            return PlaceholderSpec(x: x, y: s.bodyTop, w: colW, h: s.bodyHeight, fontSizePt: 17, themeColor: .text1, bold: false, align: .start, vAlign: .top)

        case (_, .title), (_, .centeredTitle):
            return contentHeadlineSpec(scale: scale)
        case (_, .subtitle):
            return PlaceholderSpec(x: M, y: 1_650_000, w: cW, h: 600_000, fontSizePt: 18, themeColor: .dark2, bold: false, align: .start, vAlign: .top)
        case (_, .body), (_, .object):
            let s = scale
            return PlaceholderSpec(x: M, y: s.bodyTop, w: cW, h: s.bodyHeight, fontSizePt: 18, themeColor: .text1, bold: false, align: .start, vAlign: .top)
        case (_, .picture):
            return PlaceholderSpec(x: M, y: 1_720_000, w: cW, h: 2_950_000, fontSizePt: 14, themeColor: .text1, bold: false, align: .center, vAlign: .middle)
        default:
            return nil
        }
    }

    private static var titleBandSpec: PlaceholderSpec {
        PlaceholderSpec(x: margin, y: margin, w: contentW, h: 880_000, fontSizePt: 28, themeColor: .text1, bold: true, align: .start, vAlign: .middle)
    }

    /// コンテンツスライドのヘッドラインボックス。ジオメトリは `SpacingScale` から取得し、
    /// アイブロウ（存在する場合）がボックス上端に、ヘッドラインがその下に配置されるよう上端揃え。
    /// 全コンテンツタイトルバンドレイアウトで共用するため、ヘッダー間のズレが生じない。
    public static func contentHeadlineSpec(scale: SpacingScale = .content) -> PlaceholderSpec {
        PlaceholderSpec(
            x: margin, y: scale.headerTop, w: contentW, h: scale.headerHeight,
            fontSizePt: 28, themeColor: .text1, bold: true, align: .start, vAlign: .top
        )
    }

    /// レイアウトがコンテンツヘッダー処理（アイブロウ+ヘッドライン）を使うかどうか。
    /// ステートメント/カバー/セクション/ビッグナンバーレイアウトは独自のタイトル配置を持ち、デコレーションアクセントを保持する。
    public static func usesContentHeader(_ layout: PredefinedLayout) -> Bool {
        switch layout {
        case .title, .sectionHeader, .sectionTitleAndDescription, .bigNumber, .mainPoint: false
        default: true
        }
    }

    /// アイブロウ（カテゴリキッカー）のランスタイル。小さくアクセントカラーで、アイブロウタイポグラフィ
    /// ロール（タイトルファミリーにフォールバック）で描画する。アクセントは `ACCENT1` テーマロールなので
    /// テーマと一緒にデッキ全体が再配色される — リテラルカラーは焼き込まない。
    public static func eyebrowStyle(typography: PresentationTypography, scale: SpacingScale = .content) -> TextStyle {
        let eyebrow = typography.style(for: .eyebrow)
        let title = typography.style(for: .title)
        let family = eyebrow.fontFamily ?? title.fontFamily
        let weight = eyebrow.weight
        return TextStyle(
            bold: weight == nil ? true : nil,
            fontFamily: family,
            fontSize: Dimension(magnitude: scale.eyebrowFontPt, unit: .pt),
            foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: .accent1)),
            weightedFontFamily: (family != nil || weight != nil)
                ? WeightedFontFamily(fontFamily: family, weight: weight)
                : nil
        )
    }

    /// ボディ領域を等幅の `count` カラムに分割する（ギャップあり）。シングルカラムレイアウト上に
    /// 複数ボディがある場合に使用する。テキストボディと画像ボディが同じ矩形に重なるのではなく、
    /// 横並びに配置される。
    public static func columns(of spec: PlaceholderSpec, count: Int, gap: Double = 360_000) -> [PlaceholderSpec] {
        guard count > 1 else { return [spec] }
        let colW = (spec.w - gap * Double(count - 1)) / Double(count)
        return (0..<count).map { i in
            var column = spec
            column.x = spec.x + (colW + gap) * Double(i)
            column.w = colW
            return column
        }
    }

    // MARK: - Decorations (accent rules / bars, as filled shapes — color and structure as data)

    /// 塗りつぶしアクセント矩形（レンダラーが shapeBackgroundFill を描画する）。
    static func bar(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: ThemeColorType = .accent1) -> PageElement {
        PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu),
            shape: Shape(
                shapeType: .rectangle,
                shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: color))))
            )
        )
    }

    /// レイアウトのアクセントデコレーション。スライドを「白地に黒テキスト」から引き上げる
    /// カラーと視覚構造を、レンダラーコードではなくシェイプ（データ）として表現する。
    public static func decorations(for layout: PredefinedLayout, slideId: String, scale: SpacingScale = .content) -> [PageElement] {
        let M = margin
        switch layout {
        case .title:
            // a short centered accent rule above the title
            return [bar("\(slideId)-accent", (pageW - 360_000) / 2, 1_560_000, 360_000, 78_000)]
        case .sectionHeader:
            // a bold accent rule above the section title
            return [bar("\(slideId)-accent", M, 1_770_000, 1_000_000, 96_000)]
        case .mainPoint:
            // Sit the accent just above the vertically-centered statement title so the two read as one
            // unit (the title box centers ~y2_325_000; a 1-line title's top is ~y2_060_000).
            return [bar("\(slideId)-accent", M, 1_820_000, 880_000, 84_000)]
        case .bigNumber:
            return [] // the number itself is the accent
        case .titleAndTwoColumns:
            // The eyebrow kicker carries the accent now (no floating rule). Keep only a faint vertical
            // divider in the column gap so two side-by-side bodies read as a paired comparison.
            let s = scale
            let colW = (contentW - s.columnGap) / 2
            let dividerW = 12_000.0
            let dividerX = M + colW + (s.columnGap - dividerW) / 2
            return [bar("\(slideId)-divider", dividerX, s.bodyTop + 60_000, dividerW, 1_500_000, .light2)]
        default:
            // Content title-band layouts: no decoration rule — the eyebrow kicker is the accent.
            return []
        }
    }

    /// コンテンツスライドのフッター（TITLE / SECTION はなし）。右下にミュートされたページ番号、
    /// デッキタイトルが指定された場合は左下にそのタイトルをミュートで表示する。
    /// コンテンツスライドのブランドラインは「デザインされたプレゼンテーション」の小さなシグナル（お手本デッキはランニングフッターを持つ）。
    public static func footer(
        slideId: String,
        number: Int,
        layout: PredefinedLayout,
        typography: PresentationTypography = .system,
        deckTitle: String? = nil,
        scale: SpacingScale = .content
    ) -> [PageElement] {
        switch layout {
        case .title, .sectionHeader: return []
        default:
            let s = scale
            let footerStyle = typography.style(for: .footer)

            func footerText(_ id: String, _ spec: PlaceholderSpec, _ content: String, _ align: Alignment) -> PageElement {
                PageElement(
                    objectId: id,
                    size: spec.size, transform: spec.transform,
                    shape: Shape(
                        shapeType: .textBox,
                        text: TextContent(textElements: [TextElement(
                            paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: align)),
                            textRun: TextRun(content: content, style: spec.defaultStyle))]),
                        shapeProperties: ShapeProperties(contentAlignment: .middle)
                    )
                )
            }

            let numberSpec = PlaceholderSpec(
                x: pageW - margin - 600_000, y: pageH - s.footerBottomInset, w: 600_000, h: s.footerHeight,
                fontSizePt: 11, themeColor: .dark2, bold: false, align: .end, vAlign: .middle,
                fontFamily: footerStyle.fontFamily, weight: footerStyle.weight
            )
            var elements = [footerText("\(slideId)-pageno", numberSpec, "\(number)", .end)]

            let brand = deckTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !brand.isEmpty {
                let brandSpec = PlaceholderSpec(
                    x: margin, y: pageH - s.footerBottomInset, w: contentW - 800_000, h: s.footerHeight,
                    fontSizePt: 11, themeColor: .dark2, bold: false, align: .start, vAlign: .middle,
                    fontFamily: footerStyle.fontFamily, weight: footerStyle.weight
                )
                elements.append(footerText("\(slideId)-brand", brandSpec, brand, .start))
            }
            return elements
        }
    }

    /// プレースホルダージオメトリを持つレイアウトページ。プレゼンテーションを整合した形式に
    /// するために出力する（`presentations.get` が返す形式と一致）。
    /// レイアウトごとに使用するプレースホルダータイプが、どのスロットを生成するかを決定する。
    public static func layoutPages(
        used: [(layout: PredefinedLayout, slots: [(PlaceholderType, Int)])],
        typography: PresentationTypography = .system,
        scale: SpacingScale = .content
    ) -> [Page] {
        used.map { entry in
            let elements: [PageElement] = entry.slots.compactMap { slot in
                guard let spec = spec(layout: entry.layout, type: slot.0, index: slot.1, typography: typography, scale: scale) else { return nil }
                return PageElement(
                    objectId: "\(layoutObjectId(entry.layout))-\(slot.0.rawValue)-\(slot.1)",
                    size: spec.size,
                    transform: spec.transform,
                    shape: Shape(placeholder: Placeholder(type: slot.0, index: slot.1))
                )
            }
            return Page(
                objectId: layoutObjectId(entry.layout),
                pageType: .layout,
                pageElements: elements,
                layoutProperties: LayoutProperties(name: entry.layout.rawValue, masterObjectId: masterObjectId)
            )
        }
    }

    public static func layoutObjectId(_ layout: PredefinedLayout) -> String { "layout-\(layout.rawValue)" }
}
