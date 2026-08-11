import GSlidesSchema

/// The vertical rhythm of a content slide, as EMU on the standard 16:9 page.
///
/// Every value is EMU except the two `…Pt` fields, which are typographic points because they end up
/// in a `TextStyle`. Header and body positions derive from the same scale, so swapping the scale
/// moves the whole deck together instead of letting layouts drift apart.
public struct SpacingScale: Sendable, Equatable {
    // EMU on the standard 16:9 page (PresentationTemplate.pageW/H).

    /// Top edge of the title box in EMU — the page's content margin.
    public var headerTop: Double
    /// Height of the title box in EMU, sized to hold a top-aligned eyebrow plus headline.
    public var headerHeight: Double
    /// Gap in EMU between the title box and the body area.
    public var headlineToBody: Double

    /// Point size of the eyebrow (category kicker); smaller than the headline.
    public var eyebrowFontPt: Double
    /// Space below the eyebrow paragraph, in points — the eyebrow-to-headline gap.
    public var eyebrowGapPt: Double

    /// Height in EMU of the content body area below the header.
    public var bodyHeight: Double
    /// Gap in EMU between side-by-side columns in a two-column layout.
    public var columnGap: Double
    /// Inset in EMU from the bottom of the page to the top of the footer box.
    public var footerBottomInset: Double
    /// Height of the footer box in EMU.
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

    /// The y coordinate in EMU where the body area starts, derived from the header rather than set.
    ///
    /// Nothing positions a body box independently, so a taller header pushes the body down instead
    /// of overlapping it.
    public var bodyTop: Double { headerTop + headerHeight + headlineToBody }

    /// The default content-slide rhythm: a 0.75-inch page margin and a body area below the header.
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

/// How a content slide's title zone is composed. A closed set: generation and rendering pick a case
/// rather than computing geometry, so a new look is a new case, not a new magic number.
public enum HeaderStyle: Sendable, Equatable {
    /// A small accent-colored category kicker above the headline, drawn as two paragraphs inside the
    /// one title placeholder.
    ///
    /// Pairs with a "Label: conclusion" title, which splits into eyebrow and headline. The accent is
    /// the eyebrow's color; no separate rule is drawn.
    case eyebrowHeadline
    /// A single headline with no eyebrow. The accent, if any, comes from the layout's decorations.
    case plain
}

/// The geometry and header inputs a deck is laid out from, supplied the way `ThemeSpec` supplies
/// color and `PresentationTypography` supplies fonts.
///
/// The template and expander take this and place against it rather than inventing geometry, so
/// swapping the scale or the header variant reskins every content slide at once.
///
/// This layer sits above the wire schema and only ever emits schema-shaped structures: the
/// eyebrow/headline header is one `TITLE` placeholder holding two styled paragraphs, with the accent
/// carried by a `ThemeColorType` role. There is no private element type, so a generated deck can be
/// sent to the real Slides API as-is.
public struct SlideDesignSystem: Sendable, Equatable {
    /// The vertical rhythm tokens. Swap for a tighter or roomier deck.
    public var scale: SpacingScale
    /// How content-slide headers are composed. Swap for a different title treatment.
    public var headerStyle: HeaderStyle

    public init(scale: SpacingScale = .content, headerStyle: HeaderStyle = .eyebrowHeadline) {
        self.scale = scale
        self.headerStyle = headerStyle
    }

    /// The default: the standard rhythm with eyebrow/headline headers.
    public static let standard = SlideDesignSystem()
}
