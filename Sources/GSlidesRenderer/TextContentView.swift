import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Draws a `TextContent` the way the Slides API structures it.
///
/// `textElements` is a flat stream: a `paragraphMarker` opens a paragraph and the `textRun` and
/// `autoText` elements after it are that paragraph's runs. This groups them back into paragraphs and
/// draws each as one `AttributedString`, concatenating runs and applying per-run styling — bold,
/// italic, underline, strikethrough, color, highlight, baseline offset and links — with a bullet
/// glyph prefixed and an indent per nesting level.
///
/// Handles both the shape a real `presentations.get` returns, with the marker and runs as separate
/// elements, and the compact form `PresentationExpander` emits, with both on one element.
///
/// Paragraphs whose text is entirely whitespace are dropped, so an empty placeholder draws nothing
/// rather than reserving a line.
struct TextContentView: View {
    var text: TextContent
    var placeholderType: PlaceholderType?
    /// Displayed points per schema point — the canvas scale. 1 draws at the deck's nominal size.
    var pointScale: Double
    var palette: GSlidesPalette
    /// The shrink factor the API computed for TEXT_AUTOFIT, applied to every font size.
    ///
    /// 1 means no autofit. This is not recomputed locally, so text that would overflow the box in
    /// this renderer's metrics still overflows — the value only reproduces the server's decision.
    var fontScale: Double = 1
    /// Points of line spacing TEXT_AUTOFIT removes. Clamped so spacing never goes negative.
    var lineSpacingReduction: Double = 0

    @Environment(\.gslidesSlideNumber) private var slideNumber

    var body: some View {
        // Inter-paragraph air. Bullet lists (the dominant multi-paragraph case) read cramped at the
        // old hairline gap; a roomier rhythm matches reference decks. Single-paragraph bodies/titles
        // have no inter-paragraph gap, so this only relaxes lists.
        VStack(alignment: .leading, spacing: 6 * pointScale) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph)
            }
        }
    }

    struct Run {
        var content: String
        var style: TextStyle?
    }

    struct Paragraph {
        var marker: ParagraphMarker?
        var runs: [Run]

        var plainText: String { runs.map(\.content).joined() }
    }

    /// The flat `textElements` stream grouped into paragraphs, with blank ones dropped.
    var paragraphs: [Paragraph] {
        var result: [Paragraph] = []
        var current: Paragraph?

        func appendRun(_ content: String?, _ style: TextStyle?) {
            guard let content, !content.isEmpty else { return }
            if current == nil { current = Paragraph(marker: nil, runs: []) }
            current?.runs.append(Run(content: content, style: style))
        }

        for element in text.textElements ?? [] {
            if let marker = element.paragraphMarker {
                if let open = current { result.append(open) }
                current = Paragraph(marker: marker, runs: [])
                // Compact form: the same element may also carry the first run / auto text.
                appendRun(element.textRun?.content, element.textRun?.style)
                appendRun(autoTextContent(element.autoText), element.autoText?.style)
            } else if let run = element.textRun {
                appendRun(run.content, run.style)
            } else if let auto = element.autoText {
                appendRun(autoTextContent(auto), auto.style)
            }
        }
        if let open = current { result.append(open) }
        // Drop paragraphs that carry no visible text.
        return result.filter { !$0.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The text an auto-text element should draw.
    ///
    /// A SLIDE_NUMBER field arrives with empty content because the server resolves it at present
    /// time, so the injected slide number is substituted. Without one it stays empty.
    private func autoTextContent(_ auto: AutoText?) -> String? {
        guard let auto else { return nil }
        if auto.type == .slideNumber, (auto.content ?? "").isEmpty, let number = slideNumber {
            return String(number)
        }
        return auto.content
    }

    @ViewBuilder
    private func paragraphView(_ paragraph: Paragraph) -> some View {
        let style = paragraph.marker?.style
        let nestingIndent = CGFloat(paragraph.marker?.bullet?.nestingLevel ?? 0) * 16 * CGFloat(pointScale)
        let indentStart = dimension(style?.indentStart)
        let rtl = style?.direction == .rightToLeft
        paragraphBody(paragraph, style: style, rtl: rtl)
            .lineSpacing(extraLineSpacing(style, paragraph))
            .padding(.leading, nestingIndent + indentStart)
            .padding(.trailing, dimension(style?.indentEnd))
            .padding(.top, dimension(style?.spaceAbove))
            .padding(.bottom, dimension(style?.spaceBelow))
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .minimumScaleFactor(0.3)
    }

    /// Draws a paragraph, hanging the indent on bulleted ones.
    ///
    /// A bullet's glyph and text go in separate columns so wrapped lines align under the text rather
    /// than under the glyph. Prefixing the glyph to a single string, which is the obvious approach,
    /// wraps under the bullet instead. Non-bulleted paragraphs stay one full-width text view.
    @ViewBuilder
    private func paragraphBody(_ paragraph: Paragraph, style: ParagraphStyle?, rtl: Bool) -> some View {
        let leadingAlign: SwiftUI.Alignment = rtl ? .trailing : .leading
        if let glyph = paragraph.marker?.bullet?.glyph {
            HStack(alignment: .firstTextBaseline, spacing: scaledSize(nil) * 0.4) {
                Text(styledGlyph(glyph))
                Text(attributedRuns(paragraph))
                    .frame(maxWidth: .infinity, alignment: leadingAlign)
            }
            .frame(maxWidth: .infinity, alignment: leadingAlign)
        } else {
            Text(attributed(paragraph))
                .frame(maxWidth: .infinity, alignment: frameAlignment(style?.alignment, rtl: rtl))
        }
    }

    /// The bullet glyph as a standalone styled string, so it can occupy its own column.
    ///
    /// Drawn at the placeholder's default size and text color, not the run's, so a styled first run
    /// does not restyle the marker.
    private func styledGlyph(_ glyph: String) -> AttributedString {
        var prefix = AttributedString(glyph)
        prefix.font = font(for: scaledSize(nil), style: nil)
        prefix.foregroundColor = palette.defaultText
        return prefix
    }

    /// The paragraph's runs without the bullet glyph — the text column of a hanging indent.
    private func attributedRuns(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()
        for run in paragraph.runs { result += styledRun(run) }
        return result
    }

    private func dimension(_ value: GSlidesSchema.Dimension?) -> CGFloat {
        CGFloat((value?.pointMagnitude ?? 0) * pointScale)
    }

    /// Extra space between wrapped lines.
    ///
    /// `lineSpacing` is a percentage of normal, and the autofit reduction is subtracted in points.
    /// Clamped at 0, so lines never overlap however aggressive the reduction is.
    private func extraLineSpacing(_ style: ParagraphStyle?, _ paragraph: Paragraph) -> CGFloat {
        let percent = style?.lineSpacing ?? 100
        let representative = scaledSize(paragraph.runs.first?.style)
        let extra = max(0, (percent / 100 - 1) * representative)
        return max(0, extra - CGFloat(lineSpacingReduction) * pointScale)
    }

    /// The paragraph as one styled string: an optional bullet glyph followed by each run in its own
    /// style. Used for the non-hanging path, where the glyph shares the text's wrapping column.
    private func attributed(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()
        if let glyph = paragraph.marker?.bullet?.glyph {
            var prefix = AttributedString("\(glyph)  ")
            prefix.font = font(for: scaledSize(nil), style: nil)
            prefix.foregroundColor = palette.defaultText
            result += prefix
        }
        for run in paragraph.runs {
            result += styledRun(run)
        }
        return result
    }

    /// A run's effective size on the canvas, in displayed points.
    ///
    /// Starts from the run's explicit font size, or the placeholder default when it has none, then
    /// applies the canvas scale and the autofit shrink factor.
    private func scaledSize(_ style: TextStyle?) -> CGFloat {
        let points = style?.fontSize?.pointMagnitude ?? PlaceholderTypography.defaultFontSize(for: placeholderType)
        return CGFloat(points * pointScale * fontScale)
    }

    private func styledRun(_ run: Run) -> AttributedString {
        let style = run.style
        // Paragraph breaks are modeled by separate markers, so strip any stray newlines in a run.
        var piece = AttributedString(run.content.replacingOccurrences(of: "\n", with: ""))
        let baseSize = scaledSize(style)

        let isSuperscript = style?.baselineOffset == .superscript
        let isSubscript = style?.baselineOffset == .subscript
        let size = (isSuperscript || isSubscript) ? baseSize * 0.7 : baseSize

        var font = font(for: size, style: style)
        if style?.italic == true { font = font.italic() }
        piece.font = font

        piece.foregroundColor = (style?.link != nil
            ? (palette.presentation.themeColor(.hyperlink) ?? palette.color(style?.foregroundColor))
            : palette.color(style?.foregroundColor)) ?? palette.defaultText
        if let bg = palette.color(style?.backgroundColor) { piece.backgroundColor = bg }
        if style?.underline == true || style?.link != nil { piece.underlineStyle = .single }
        if style?.strikethrough == true { piece.strikethroughStyle = .single }
        if isSuperscript { piece.baselineOffset = baseSize * 0.34 }
        if isSubscript { piece.baselineOffset = -baseSize * 0.18 }
        if let link = style?.link?.url.flatMap(URL.init(string:)) { piece.link = link }
        return piece
    }

    /// Resolves a run's font from the schema.
    ///
    /// A family name from either `fontFamily` or the weighted family is honored through
    /// `Font.custom`, with the numeric weight mapped to a `Font.Weight`. With neither set this falls
    /// back to the system font at the placeholder's default weight, so a deck that specifies no
    /// typography still renders.
    ///
    /// A family name that is not installed silently resolves to the system font — there is no
    /// signal that the deck's intended face was unavailable.
    private func font(for size: CGFloat, style: TextStyle?) -> Font {
        let weight = resolvedWeight(style)
        let family = (style?.fontFamily ?? style?.weightedFontFamily?.fontFamily)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let family, !family.isEmpty {
            // An unavailable family name falls back to the system font automatically.
            return Font.custom(family, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    /// The effective weight, in precedence order: an explicit numeric weight, then the bold flag,
    /// then the placeholder's default. A numeric weight therefore overrides `bold`.
    private func resolvedWeight(_ style: TextStyle?) -> Font.Weight {
        if let numeric = style?.weightedFontFamily?.weight {
            return Self.fontWeight(numeric: numeric)
        }
        if style?.bold == true { return .bold }
        return PlaceholderTypography.weight(for: placeholderType)
    }

    /// Maps a numeric font weight of 100–900 to the nearest `Font.Weight`. Values outside that range
    /// clamp to `.ultraLight` and `.black`.
    static func fontWeight(numeric weight: Int) -> Font.Weight {
        switch weight {
        case ..<150: .ultraLight
        case 150..<250: .thin
        case 250..<350: .light
        case 350..<450: .regular
        case 450..<550: .medium
        case 550..<650: .semibold
        case 650..<750: .bold
        case 750..<850: .heavy
        default: .black
        }
    }

    private func frameAlignment(_ alignment: GSlidesSchema.Alignment?, rtl: Bool = false) -> SwiftUI.Alignment {
        switch alignment {
        case .some(.center): .center
        case .some(.end): rtl ? .leading : .trailing
        case .some(.start): rtl ? .trailing : .leading
        default:
            if placeholderType == .centeredTitle { .center } else { rtl ? .trailing : .leading }
        }
    }
}
