import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Renders TextContent the way the Slides API structures it: `textElements` is a flat stream where
/// a `paragraphMarker` opens a paragraph and the following `textRun` / `autoText` elements are its
/// runs. We group them into paragraphs, then render each as one line — an `AttributedString` that
/// concatenates the runs with per-run styling (bold/italic/underline/strike/color/highlight/
/// baseline/link), prefixed by the bullet glyph and indented by nesting level.
///
/// This handles both a real `presentations.get` (marker and runs in separate elements) and the
/// compact form `PresentationExpander` emits (marker + run in one element).
struct TextContentView: View {
    var text: TextContent
    var placeholderType: PlaceholderType?
    /// Display points per profile point (canvas scale).
    var pointScale: Double
    var palette: GSlidesPalette
    /// Shape autofit (TEXT_AUTOFIT): the API-computed shrink factor applied to every font size.
    var fontScale: Double = 1
    /// Shape autofit: points to subtract from inter-line spacing.
    var lineSpacingReduction: Double = 0

    @Environment(\.gslidesSlideNumber) private var slideNumber

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * pointScale) {
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

    /// Group the flat `textElements` stream into paragraphs.
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

    /// AutoText content — SLIDE_NUMBER fields arrive with empty content (resolved at present time),
    /// so substitute the injected slide number.
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
        let nestingIndent = CGFloat(paragraph.marker?.bullet?.nestingLevel ?? 0) * 16 * pointScale
        let indentStart = dimension(style?.indentStart)
        let rtl = style?.direction == .rightToLeft
        Text(attributed(paragraph))
            .lineSpacing(extraLineSpacing(style, paragraph))
            .frame(maxWidth: .infinity, alignment: frameAlignment(style?.alignment, rtl: rtl))
            .padding(.leading, nestingIndent + indentStart)
            .padding(.trailing, dimension(style?.indentEnd))
            .padding(.top, dimension(style?.spaceAbove))
            .padding(.bottom, dimension(style?.spaceBelow))
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .minimumScaleFactor(0.3)
    }

    private func dimension(_ value: GSlidesSchema.Dimension?) -> CGFloat {
        CGFloat((value?.pointMagnitude ?? 0) * pointScale)
    }

    /// Extra spacing between wrapped lines: `lineSpacing` is a percentage of normal; autofit's
    /// `lineSpacingReduction` (points) is then subtracted. Clamped to ≥ 0.
    private func extraLineSpacing(_ style: ParagraphStyle?, _ paragraph: Paragraph) -> CGFloat {
        let percent = style?.lineSpacing ?? 100
        let representative = scaledSize(paragraph.runs.first?.style)
        let extra = max(0, (percent / 100 - 1) * representative)
        return max(0, extra - CGFloat(lineSpacingReduction) * pointScale)
    }

    /// Build the paragraph's styled string: optional bullet glyph + each run with its own style.
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

    /// A run's effective point size on the canvas (explicit size or placeholder default), with the
    /// canvas scale and autofit font scale applied.
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

    /// Resolve a run's font from the Slides schema: honor `fontFamily` (`TextStyle` or the weighted
    /// family) via `Font.custom`, and the numeric weight (100–900) via `Font.Weight`. Falls back to
    /// the system font and the placeholder's default weight when the schema leaves them unset, so a
    /// presentation that specifies no typography renders exactly as before.
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

    /// Effective SwiftUI weight: an explicit numeric weight (100–900) wins; otherwise the bold flag;
    /// otherwise the placeholder's default weight.
    private func resolvedWeight(_ style: TextStyle?) -> Font.Weight {
        if let numeric = style?.weightedFontFamily?.weight {
            return Self.fontWeight(numeric: numeric)
        }
        if style?.bold == true { return .bold }
        return PlaceholderTypography.weight(for: placeholderType)
    }

    /// Map a Google Slides numeric font weight (100–900) to the nearest `Font.Weight`.
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
