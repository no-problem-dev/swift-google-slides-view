import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Slides API の構造に従って TextContent を描画する。`textElements` はフラットなストリームで、
/// `paragraphMarker` がパラグラフを開き、続く `textRun` / `autoText` 要素がそのランになる。
/// これらをパラグラフにグループ化し、各パラグラフを 1 行として描画する。`AttributedString` はランを
/// 連結してランごとのスタイル（bold/italic/underline/strike/color/highlight/baseline/link）を適用し、
/// 箇条書きグリフを先頭に付けてネストレベルに応じてインデントする。
///
/// 実際の `presentations.get`（マーカーとランが別要素）と `PresentationExpander` が出力する
/// コンパクト形式（マーカー + ランが同一要素）の両方を処理する。
struct TextContentView: View {
    var text: TextContent
    var placeholderType: PlaceholderType?
    /// プロファイルポイントあたりの表示ポイント（キャンバススケール）。
    var pointScale: Double
    var palette: GSlidesPalette
    /// シェイプオートフィット（TEXT_AUTOFIT）: API が算出した全フォントサイズに適用する縮小係数。
    var fontScale: Double = 1
    /// シェイプオートフィット: 行間スペースから減算するポイント数。
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

    /// フラットな `textElements` ストリームをパラグラフにグループ化する。
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

    /// AutoText コンテンツ。SLIDE_NUMBER フィールドはコンテンツが空の状態で到着する（プレゼンテーション時に解決）。
    /// 注入されたスライド番号で代替する。
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

    /// 箇条書きパラグラフはマーカーとテキストを別カラムとして描画し、折り返し行をハングさせる
    /// — 折り返しはバレット下ではなくテキスト下に揃える（プロフェッショナルなデフォルト。単一の
    /// プレフィックス文字列ではバレット下に折り返してしまう）。箇条書きでないパラグラフは全幅の単一 Text を保持する。
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

    /// バレットマーカーをスタンドアロンのスタイル付き文字列として返す（独自カラムに配置できるよう）。
    private func styledGlyph(_ glyph: String) -> AttributedString {
        var prefix = AttributedString(glyph)
        prefix.font = font(for: scaledSize(nil), style: nil)
        prefix.foregroundColor = palette.defaultText
        return prefix
    }

    /// バレットグリフを除いたパラグラフのラン（ハンギングインデントのテキストカラム）。
    private func attributedRuns(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()
        for run in paragraph.runs { result += styledRun(run) }
        return result
    }

    private func dimension(_ value: GSlidesSchema.Dimension?) -> CGFloat {
        CGFloat((value?.pointMagnitude ?? 0) * pointScale)
    }

    /// 折り返し行間の追加スペース。`lineSpacing` は通常の割合で、オートフィットの
    /// `lineSpacingReduction`（ポイント）を差し引く。0 以上にクランプする。
    private func extraLineSpacing(_ style: ParagraphStyle?, _ paragraph: Paragraph) -> CGFloat {
        let percent = style?.lineSpacing ?? 100
        let representative = scaledSize(paragraph.runs.first?.style)
        let extra = max(0, (percent / 100 - 1) * representative)
        return max(0, extra - CGFloat(lineSpacingReduction) * pointScale)
    }

    /// パラグラフのスタイル付き文字列を構築する: オプションのバレットグリフ + 各ランに独自スタイル。
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

    /// キャンバス上のランの有効ポイントサイズ（明示的なサイズまたはプレースホルダーのデフォルト）。
    /// キャンバススケールとオートフィットフォントスケールを適用した値。
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

    /// Slides スキーマからランのフォントを解決する。`fontFamily`（`TextStyle` またはウェイト付きファミリー）を
    /// `Font.custom` で尊重し、数値ウェイト（100–900）を `Font.Weight` で適用する。
    /// スキーマで未設定の場合はシステムフォントとプレースホルダーのデフォルトウェイトにフォールバックする。
    /// タイポグラフィを指定しないプレゼンテーションは従来通り描画される。
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

    /// 有効な SwiftUI ウェイト: 明示的な数値ウェイト（100–900）が最優先。次に bold フラグ。
    /// それ以外はプレースホルダーのデフォルトウェイト。
    private func resolvedWeight(_ style: TextStyle?) -> Font.Weight {
        if let numeric = style?.weightedFontFamily?.weight {
            return Self.fontWeight(numeric: numeric)
        }
        if style?.bold == true { return .bold }
        return PlaceholderTypography.weight(for: placeholderType)
    }

    /// Google Slides の数値フォントウェイト（100–900）を最も近い `Font.Weight` にマッピングする。
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
