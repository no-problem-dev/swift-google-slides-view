import GSlidesSchema

/// Which baked-in theme a generated presentation uses. A presentation is an immutable document, so this is the
/// document's own theme (it does NOT track the viewer's dark mode) — selected at generation time.
/// Both variants are valid Slides `ColorScheme`s; only the master's RGB values differ, so every
/// placeholder/decoration (which references theme colors symbolically) recolors automatically.
public enum PresentationColorTheme: String, Sendable, CaseIterable, Codable {
    case light, dark
}

/// Placeholder geometry + default text style for one slot of a layout — the unit of slide design,
/// expressed as data (EMU rect + style) exactly as a real Google Slides layout page carries it.
public struct PlaceholderSpec: Sendable {
    public var x, y, w, h: Double          // EMU on the standard 16:9 page
    public var fontSizePt: Double
    public var themeColor: ThemeColorType
    public var bold: Bool
    public var align: Alignment            // horizontal text alignment
    public var vAlign: ContentAlignment    // vertical alignment within the box

    public var size: Size {
        Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu))
    }
    public var transform: AffineTransform {
        AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu)
    }
    public var defaultStyle: TextStyle {
        TextStyle(
            bold: bold,
            fontSize: Dimension(magnitude: fontSizePt, unit: .pt),
            foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: themeColor))
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
    static let gap: Double = 400_000

    public static let masterObjectId = "gslides-master"

    /// A clean, professional default theme. Unbranded presentations still get color (accent + muted captions),
    /// resolved through the same PresentationColorPalette path as a branded presentation's scheme. The `theme`
    /// selects light vs dark — only the master `ColorScheme` differs; every placeholder/decoration
    /// references these slots symbolically (`.text1`/`.dark2`/`.accent1`), so they recolor for free.
    public static func master(theme: PresentationColorTheme = .light) -> Page {
        Page(
            objectId: masterObjectId,
            pageType: .master,
            pageProperties: PageProperties(colorScheme: colorScheme(theme)),
            masterProperties: MasterProperties(displayName: theme == .dark ? "GSlides Dark" : "GSlides Default")
        )
    }

    /// The master `ColorScheme` per theme — enumerating all 16 `ThemeColorType`s exactly as a real
    /// `presentations.get` master does (`dark1`/`light1` = first dark/light, `dark2`/`light2` = second,
    /// `accent1…6`, `hyperlink`/`followedHyperlink`). `text1`/`background1`/`text2`/`background2` are
    /// the API's aliases — emitted with the conventional mapping (text1→dark1, background1→light1,
    /// text2→dark2, background2→light2). The renderer reads dark1/light1 for canvas + text, accent1
    /// for the brand accent, dark2 for muted captions; the rest complete protocol fidelity.
    static func colorScheme(_ theme: PresentationColorTheme) -> ColorScheme {
        switch theme {
        case .light:
            scheme(
                dark1: RgbColor(red: 0.11, green: 0.13, blue: 0.16),   // primary text / on-canvas
                light1: RgbColor(red: 1, green: 1, blue: 1),           // canvas
                dark2: RgbColor(red: 0.42, green: 0.46, blue: 0.51),   // muted captions
                light2: RgbColor(red: 0.93, green: 0.94, blue: 0.96),  // tinted surface
                accent1: RgbColor(red: 0.0, green: 0.47, blue: 0.56),
                accent2: RgbColor(red: 0.91, green: 0.45, blue: 0.23),
                accent3: RgbColor(red: 0.18, green: 0.62, blue: 0.42),
                accent4: RgbColor(red: 0.88, green: 0.66, blue: 0.18),
                accent5: RgbColor(red: 0.42, green: 0.36, blue: 0.65),
                accent6: RgbColor(red: 0.78, green: 0.29, blue: 0.49),
                hyperlink: RgbColor(red: 0.10, green: 0.45, blue: 0.91),
                followedHyperlink: RgbColor(red: 0.42, green: 0.25, blue: 0.63)
            )
        case .dark:
            // text/background swap to a near-black canvas; accents brighten for contrast on dark.
            scheme(
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
                followedHyperlink: RgbColor(red: 0.72, green: 0.61, blue: 0.88)
            )
        }
    }

    /// Builds the full 16-entry `ColorScheme`, deriving the four alias slots from their concrete
    /// counterparts (text1=dark1, background1=light1, text2=dark2, background2=light2).
    private static func scheme(
        dark1: RgbColor, light1: RgbColor, dark2: RgbColor, light2: RgbColor,
        accent1: RgbColor, accent2: RgbColor, accent3: RgbColor, accent4: RgbColor,
        accent5: RgbColor, accent6: RgbColor, hyperlink: RgbColor, followedHyperlink: RgbColor
    ) -> ColorScheme {
        ColorScheme(colors: [
            ThemeColorPair(type: .dark1, color: dark1),
            ThemeColorPair(type: .light1, color: light1),
            ThemeColorPair(type: .dark2, color: dark2),
            ThemeColorPair(type: .light2, color: light2),
            ThemeColorPair(type: .accent1, color: accent1),
            ThemeColorPair(type: .accent2, color: accent2),
            ThemeColorPair(type: .accent3, color: accent3),
            ThemeColorPair(type: .accent4, color: accent4),
            ThemeColorPair(type: .accent5, color: accent5),
            ThemeColorPair(type: .accent6, color: accent6),
            ThemeColorPair(type: .hyperlink, color: hyperlink),
            ThemeColorPair(type: .followedHyperlink, color: followedHyperlink),
            ThemeColorPair(type: .text1, color: dark1),
            ThemeColorPair(type: .background1, color: light1),
            ThemeColorPair(type: .text2, color: dark2),
            ThemeColorPair(type: .background2, color: light2),
        ])
    }

    /// The placeholder spec for a slot, or nil if this layout doesn't define it (renderer then
    /// falls back to its semantic stack layout for that element).
    public static func spec(layout: PredefinedLayout, type: PlaceholderType, index: Int) -> PlaceholderSpec? {
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
            return titleBandSpec
        case (.titleAndTwoColumns, .body):
            let colW = (cW - gap) / 2
            let x = index == 0 ? M : M + colW + gap
            return PlaceholderSpec(x: x, y: 1_720_000, w: colW, h: 2_950_000, fontSizePt: 17, themeColor: .text1, bold: false, align: .start, vAlign: .top)

        case (_, .title), (_, .centeredTitle):
            return titleBandSpec
        case (_, .subtitle):
            return PlaceholderSpec(x: M, y: 1_650_000, w: cW, h: 600_000, fontSizePt: 18, themeColor: .dark2, bold: false, align: .start, vAlign: .top)
        case (_, .body), (_, .object):
            return PlaceholderSpec(x: M, y: 1_720_000, w: cW, h: 2_950_000, fontSizePt: 18, themeColor: .text1, bold: false, align: .start, vAlign: .top)
        case (_, .picture):
            return PlaceholderSpec(x: M, y: 1_720_000, w: cW, h: 2_950_000, fontSizePt: 14, themeColor: .text1, bold: false, align: .center, vAlign: .middle)
        default:
            return nil
        }
    }

    private static var titleBandSpec: PlaceholderSpec {
        PlaceholderSpec(x: margin, y: margin, w: contentW, h: 880_000, fontSizePt: 28, themeColor: .text1, bold: true, align: .start, vAlign: .middle)
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
    public static func decorations(for layout: PredefinedLayout, slideId: String) -> [PageElement] {
        let M = margin
        switch layout {
        case .title:
            // a short centered accent rule above the title
            return [bar("\(slideId)-accent", (pageW - 360_000) / 2, 1_560_000, 360_000, 78_000)]
        case .sectionHeader:
            // a bold accent rule above the section title
            return [bar("\(slideId)-accent", M, 1_770_000, 1_000_000, 96_000)]
        case .mainPoint:
            return [bar("\(slideId)-accent", M, 1_460_000, 880_000, 84_000)]
        case .bigNumber:
            return [] // the number itself is the accent
        default:
            // title-band layouts: accent underline in the gap below the title band (y 685800+880000
            // = 1_565_800) and above the body (y 1_720_000) — never inside the title box.
            return [bar("\(slideId)-accent", M, 1_610_000, 880_000, 72_000)]
        }
    }

    /// Page-number footer text for content slides (TITLE / SECTION get none). Baked as plain text
    /// styled muted at bottom-right — a small "designed presentation" signal.
    public static func footer(slideId: String, number: Int, layout: PredefinedLayout) -> PageElement? {
        switch layout {
        case .title, .sectionHeader: return nil
        default:
            let spec = PlaceholderSpec(x: pageW - margin - 600_000, y: pageH - 520_000, w: 600_000, h: 300_000, fontSizePt: 11, themeColor: .dark2, bold: false, align: .end, vAlign: .middle)
            return PageElement(
                objectId: "\(slideId)-pageno",
                size: spec.size, transform: spec.transform,
                shape: Shape(
                    shapeType: .textBox,
                    text: TextContent(textElements: [TextElement(
                        paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .end)),
                        textRun: TextRun(content: "\(number)", style: spec.defaultStyle))]),
                    shapeProperties: ShapeProperties(contentAlignment: .middle)
                )
            )
        }
    }

    /// Layout pages carrying the placeholder geometry — emitted so the presentation is well-formed
    /// (and matches what `presentations.get` returns). The used placeholder types per layout drive
    /// which slots appear.
    public static func layoutPages(used: [(layout: PredefinedLayout, slots: [(PlaceholderType, Int)])]) -> [Page] {
        used.map { entry in
            let elements: [PageElement] = entry.slots.compactMap { slot in
                guard let spec = spec(layout: entry.layout, type: slot.0, index: slot.1) else { return nil }
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
