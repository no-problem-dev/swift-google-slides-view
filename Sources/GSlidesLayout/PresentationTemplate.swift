import GSlidesSchema

/// One layout slot: where a placeholder sits and what its text looks like by default.
///
/// Holds the same shape a real Google Slides layout page does — an EMU rectangle plus a style — so
/// `size`, `transform` and `defaultStyle` can be dropped straight onto a `PageElement`.
public struct PlaceholderSpec: Sendable {
    public var x, y, w, h: Double          // EMU on the standard 16:9 page; x, y is the upper-left corner
    /// Font size in typographic points, not EMU.
    public var fontSizePt: Double
    /// The theme slot the text color resolves through, so the deck recolors with its master.
    public var themeColor: ThemeColorType
    public var bold: Bool
    public var align: Alignment            // horizontal text alignment
    public var vAlign: ContentAlignment    // vertical alignment inside the box
    /// The typography intent, mapped to Slides `TextStyle.fontFamily` / `weightedFontFamily`.
    ///
    /// With both nil the renderer uses the system font at the placeholder's default weight.
    public var fontFamily: String?         // e.g. "Hiragino Sans" — applied as the run's font family
    public var weight: Int?                // numeric font weight 100–900; finer-grained than the bold flag

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

    /// The slot's `w` × `h` as an EMU `Size`.
    public var size: Size {
        Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu))
    }
    /// An unscaled EMU transform that translates to the slot's upper-left corner.
    public var transform: AffineTransform {
        AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu)
    }
    /// The slot's default run style: size in points, color as a theme slot, family and weight when set.
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

/// A deck's design expressed as data: a master color scheme, plus the placeholder rectangles and
/// default styles for each predefined layout.
///
/// The look lives in the protocol's own vocabulary — master and layout pages — rather than in
/// renderer code, which is the same place a real `presentations.get` keeps it. `PresentationExpander`
/// borrows these specs so a generated deck goes through the identical geometry path as a fetched one.
///
/// All coordinates are EMU on the standard 16:9 page (9,144,000 × 5,143,500).
public enum PresentationTemplate {
    // Standard 16:9 page (EMU) and a comfortable margin.
    static let pageW: Double = 9_144_000
    static let pageH: Double = 5_143_500
    static let margin: Double = 685_800          // 0.75"
    static var contentW: Double { pageW - 2 * margin }

    public static let masterObjectId = "gslides-master"

    /// A master page carrying `theme` as its color scheme.
    ///
    /// Placeholders and decorations reference slots symbolically (`.text1`, `.dark2`, `.accent1`)
    /// rather than baking in literal RGB, so replacing this master recolors the whole deck.
    public static func master(theme: ThemeSpec, displayName: String = "GSlides Theme") -> Page {
        Page(
            objectId: masterObjectId,
            pageType: .master,
            pageProperties: PageProperties(colorScheme: theme.colorScheme),
            masterProperties: MasterProperties(displayName: displayName)
        )
    }


    /// The placeholder spec for a slot, with the typography scale layered onto the base geometry.
    ///
    /// The scale only fills in nil fields, so a slot that already pins a family or weight keeps it.
    ///
    /// - Returns: nil when this layout defines no such slot. Callers treat that as "place it
    ///   yourself" rather than an error.
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

    /// The typography role a slot draws its family and weight from. Color is orthogonal and comes
    /// from the theme.
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

    /// The slot's geometry and non-typographic style — the layout design itself.
    /// `spec(layout:type:index:typography:scale:)` layers the type scale on top of this.
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

    /// The headline box shared by every content title-band layout.
    ///
    /// Geometry comes from the spacing scale and the box is top-aligned so the eyebrow, when present,
    /// sits at the top with the headline beneath it. Shared rather than per-layout, so headers cannot
    /// drift apart between slides.
    public static func contentHeadlineSpec(scale: SpacingScale = .content) -> PlaceholderSpec {
        PlaceholderSpec(
            x: margin, y: scale.headerTop, w: contentW, h: scale.headerHeight,
            fontSizePt: 28, themeColor: .text1, bold: true, align: .start, vAlign: .top
        )
    }

    /// Whether a layout uses the eyebrow-plus-headline content header.
    ///
    /// False for the cover, section, big-number and main-point layouts: they place their titles
    /// themselves and keep a drawn accent rule instead of an eyebrow.
    public static func usesContentHeader(_ layout: PredefinedLayout) -> Bool {
        switch layout {
        case .title, .sectionHeader, .sectionTitleAndDescription, .bigNumber, .mainPoint: false
        default: true
        }
    }

    /// The run style for the eyebrow: small, accent-colored, in the eyebrow role's font.
    ///
    /// Falls back to the title family when the eyebrow role sets none. The color is the `ACCENT1`
    /// theme slot rather than a literal RGB, so it recolors with the theme.
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

    /// Splits a spec into `count` equal-width columns separated by `gap` EMU.
    ///
    /// Used when a single-column layout carries more than one body, so a text body and an image body
    /// end up side by side instead of stacked in the same rectangle. `count` of 1 or less returns the
    /// spec unchanged; a gap wider than the box yields negative widths rather than clamping.
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

    /// A filled accent rectangle, positioned and sized in EMU. The renderer draws it via
    /// `shapeBackgroundFill`.
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

    /// The accent shapes for a layout, as ordinary filled elements rather than renderer-side drawing.
    ///
    /// Returns an empty array for layouts whose accent is carried by the eyebrow instead. Object IDs
    /// are derived from `slideId`, so calling this twice for the same slide produces colliding IDs.
    /// Emit them once, before the slide's content, since they are meant to sit underneath it.
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

    /// The footer band for a content slide: a muted page number at bottom right, and the deck title
    /// at bottom left when one is given.
    ///
    /// Returns an empty array for the cover and section layouts, which carry no footer. As with
    /// decorations, object IDs derive from `slideId`, so call this once per slide.
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

    /// Layout pages carrying the placeholder geometry for the slots a deck actually uses.
    ///
    /// Emitted so a generated presentation has the same shape as one from `presentations.get`, which
    /// is what lets `PlaceholderResolver` resolve inherited geometry. Slots not listed in `used` get
    /// no element, and a slot this template does not define is skipped silently.
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
