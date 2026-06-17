import GSlidesSchema

/// Placeholder geometry + default text style for one slot of a layout — the unit of slide design,
/// expressed as data (EMU rect + style) exactly as a real Google Slides layout page carries it.
public struct PlaceholderSpec: Sendable {
    public var x, y, w, h: Double          // EMU on the standard 16:9 page
    public var fontSizePt: Double
    public var themeColor: ThemeColorType
    public var bold: Bool
    public var align: Alignment            // horizontal text alignment
    public var vAlign: ContentAlignment    // vertical alignment within the box
    /// Typography intent (Slides `TextStyle.fontFamily` / `weightedFontFamily`). Both nil → the
    /// renderer uses the system font + the placeholder's default weight (the historical behavior).
    public var fontFamily: String?         // e.g. "Hiragino Sans" — applied as the run's font family
    public var weight: Int?                // numeric font weight 100–900 (finer than the bold flag)

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

/// A presentation design as data: the master's theme (ColorScheme) and, per predefined layout, the
/// placeholder rectangles + default styles. This is where "見た目" lives — in the protocol's own
/// vocabulary (layout/master pages), not in renderer code. Real `presentations.get` presentations carry the
/// same data; LLM presentations borrow it via `PresentationExpander`, then render through the identical geometry path.
public enum PresentationTemplate {
    // Standard 16:9 page (EMU) and a comfortable margin.
    static let pageW: Double = 9_144_000
    static let pageH: Double = 5_143_500
    static let margin: Double = 685_800          // 0.75"
    static var contentW: Double { pageW - 2 * margin }

    public static let masterObjectId = "gslides-master"

    /// The master page carrying an arbitrary design intent's color scheme. Any `ThemeSpec` (the 12
    /// editable slots) bakes into the master's `ColorScheme`; every placeholder/decoration references
    /// those slots symbolically (`.text1`/`.dark2`/`.accent1`), so the whole deck recolors for free.
    public static func master(theme: ThemeSpec, displayName: String = "GSlides Theme") -> Page {
        Page(
            objectId: masterObjectId,
            pageType: .master,
            pageProperties: PageProperties(colorScheme: theme.colorScheme),
            masterProperties: MasterProperties(displayName: displayName)
        )
    }


    /// The placeholder spec for a slot, or nil if this layout doesn't define it (renderer then
    /// falls back to its semantic stack layout for that element). The `typography` scale overlays a
    /// font family + weight onto the geometry per the slot's semantic role (fill-if-nil, so a slot
    /// that already pins typography keeps it). `.system` leaves the historical system-font default.
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

    /// The semantic typographic role a slot maps to — drives which `PresentationTypography` entry a
    /// placeholder draws its family/weight from. Color stays orthogonal (theme owns it).
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

    /// The placeholder geometry + default (non-typography) style for a slot — the layout design as
    /// data. `spec(...)` overlays the typography scale on top of this.
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

    /// The content-slide headline box: geometry comes from the one `SpacingScale`, top-aligned so the
    /// eyebrow (when present) sits at the box top and the headline below it. Used for every content
    /// title-band layout, so their headers can't drift apart.
    public static func contentHeadlineSpec(scale: SpacingScale = .content) -> PlaceholderSpec {
        PlaceholderSpec(
            x: margin, y: scale.headerTop, w: contentW, h: scale.headerHeight,
            fontSizePt: 28, themeColor: .text1, bold: true, align: .start, vAlign: .top
        )
    }

    /// Whether a layout uses the content header treatment (eyebrow+headline). Statement/cover/section/
    /// big-number layouts have their own title placement and keep their decoration accent.
    public static func usesContentHeader(_ layout: PredefinedLayout) -> Bool {
        switch layout {
        case .title, .sectionHeader, .sectionTitleAndDescription, .bigNumber, .mainPoint: false
        default: true
        }
    }

    /// The run style for the eyebrow (category kicker): small, accent-colored, drawn with the eyebrow
    /// typography role (falling back to the title family). Accent is the `ACCENT1` theme role, so the
    /// whole deck recolors with the theme — no literal color is baked in.
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

    /// Divides a body region into `count` equal-width columns (with gaps). Used when a slide carries
    /// more than one body on a single-column layout: multiple bodies = multiple columns, so a text
    /// body and an image body sit side by side instead of stacking in the same rect.
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

    /// A filled accent rectangle (the renderer draws shapeBackgroundFill).
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

    /// Accent decorations for a layout — color and visual structure that lift a slide above
    /// "black text on white", expressed as shapes (data), not renderer code.
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

    /// Footer for content slides (TITLE / SECTION get none): the page number muted at bottom-right,
    /// plus — when a deck title is supplied — that title muted at bottom-left. The brand line on every
    /// content slide is a small "designed presentation" signal (お手本 decks carry a running footer).
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

    /// Layout pages carrying the placeholder geometry — emitted so the presentation is well-formed
    /// (and matches what `presentations.get` returns). The used placeholder types per layout drive
    /// which slots appear.
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
