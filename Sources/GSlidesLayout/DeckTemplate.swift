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

/// A deck design as data: the master's theme (ColorScheme) and, per predefined layout, the
/// placeholder rectangles + default styles. This is where "見た目" lives — in the protocol's own
/// vocabulary (layout/master pages), not in renderer code. Real `presentations.get` decks carry the
/// same data; LLM decks borrow it via `DeckExpander`, then render through the identical geometry path.
public enum DeckTemplate {
    // Standard 16:9 page (EMU) and a comfortable margin.
    static let pageW: Double = 9_144_000
    static let pageH: Double = 5_143_500
    static let margin: Double = 685_800          // 0.75"
    static var contentW: Double { pageW - 2 * margin }
    static let gap: Double = 400_000

    public static let masterObjectId = "gslides-master"

    /// A clean, professional default theme. Unbranded decks still get color (accent + muted captions),
    /// resolved through the same DeckColorPalette path as a branded deck's scheme.
    public static func master() -> Page {
        Page(
            objectId: masterObjectId,
            pageType: .master,
            pageProperties: PageProperties(colorScheme: ColorScheme(colors: [
                ThemeColorPair(type: .text1, color: RgbColor(red: 0.11, green: 0.13, blue: 0.16)),
                ThemeColorPair(type: .dark1, color: RgbColor(red: 0.11, green: 0.13, blue: 0.16)),
                ThemeColorPair(type: .background1, color: RgbColor(red: 1, green: 1, blue: 1)),
                ThemeColorPair(type: .light1, color: RgbColor(red: 1, green: 1, blue: 1)),
                ThemeColorPair(type: .accent1, color: RgbColor(red: 0.0, green: 0.47, blue: 0.56)),
                ThemeColorPair(type: .dark2, color: RgbColor(red: 0.42, green: 0.46, blue: 0.51)),
                ThemeColorPair(type: .light2, color: RgbColor(red: 0.93, green: 0.94, blue: 0.96)),
            ])),
            masterProperties: MasterProperties(displayName: "GSlides Default")
        )
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
