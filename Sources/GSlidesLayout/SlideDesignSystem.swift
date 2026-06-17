import GSlidesSchema

/// The design-system layer for slide geometry: a vertical-rhythm scale and a small, finite set of
/// header treatments. The point is the same one `ThemeSpec` (color) and `PresentationTypography`
/// (font) already make for their domains — express the *design* as swappable tokens/variants, not as
/// magic numbers scattered across per-layout geometry. Consistency is enforced by construction: a
/// content slide's header and body share one scale, so they cannot drift between layouts.
///
/// This layer sits *above* the Google Slides wire schema (`GSlidesSchema`) and only ever emits
/// schema-conformant structures: the eyebrow/headline header is a single `TITLE` placeholder carrying
/// two styled paragraphs (Slides' native text model) + a `ThemeColorType` role for the accent — never
/// a bespoke element — so a generated deck round-trips to the real Slides API unchanged.
public struct SpacingScale: Sendable, Equatable {
    // EMU on the standard 16:9 page (PresentationTemplate.pageW/H).

    /// Top of the title box (page content margin).
    public var headerTop: Double
    /// Title box height. Holds the eyebrow + headline paragraphs, top-aligned.
    public var headerHeight: Double
    /// Gap from the title box to the body region.
    public var headlineToBody: Double

    /// Eyebrow (category kicker) point size — small relative to the headline.
    public var eyebrowFontPt: Double
    /// Space below the eyebrow paragraph (the eyebrow → headline gap), in points.
    public var eyebrowGapPt: Double

    /// Height of the content body region below the header.
    public var bodyHeight: Double
    /// Gap between side-by-side columns (two-column layout, paired-comparison divider).
    public var columnGap: Double
    /// Footer band: box inset from the page bottom edge, and the footer box height.
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

    /// The y where the body region starts for a content slide — derived from the header, never
    /// hand-placed, so header and body share one source of truth and stay in rhythm.
    public var bodyTop: Double { headerTop + headerHeight + headlineToBody }

    /// Default content-slide rhythm.
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

/// How a content slide's header (the title zone) is composed. A finite set — generation and rendering
/// *choose* a variant, they never invent geometry. New looks are added as cases, not as new magic
/// numbers, which is what keeps the system both swappable and consistent.
public enum HeaderStyle: Sendable, Equatable {
    /// A small accent-colored category kicker above a large headline, realized as two paragraphs in
    /// the title placeholder. Pairs with "ラベル：結論" titles: the label becomes the eyebrow, the
    /// conclusion the headline. The accent lives as the eyebrow's color — no separate floating rule.
    case eyebrowHeadline
    /// A single headline, no eyebrow (the historical single-line title). Accent handled by decorations.
    case plain
}

/// The full design-system input for a deck's geometry + header treatment, bundled so a profile or
/// theme can supply it the same way it already supplies color (`ThemeSpec`) and typography
/// (`PresentationTypography`). The template/expander *receive* this and place accordingly — they never
/// invent geometry, so swapping the scale or the header variant reskins every content slide at once
/// while the consistency invariants (one scale → header and body can't drift) still hold by construction.
public struct SlideDesignSystem: Sendable, Equatable {
    /// Vertical-rhythm tokens. Swap for a denser/looser deck.
    public var scale: SpacingScale
    /// How content-slide headers are composed. Swap for a different title treatment.
    public var headerStyle: HeaderStyle

    public init(scale: SpacingScale = .content, headerStyle: HeaderStyle = .eyebrowHeadline) {
        self.scale = scale
        self.headerStyle = headerStyle
    }

    /// The default content-slide design system: the standard rhythm + eyebrow/headline header.
    public static let standard = SlideDesignSystem()
}
