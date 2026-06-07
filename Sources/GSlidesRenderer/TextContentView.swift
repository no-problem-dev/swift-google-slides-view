import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Renders TextContent: one line per paragraph-bearing text element,
/// bullets prefixed with their glyph, run styles applied per line.
struct TextContentView: View {
    var text: TextContent
    var placeholderType: PlaceholderType?
    /// Display points per profile point (canvas scale).
    var pointScale: Double
    var palette: GSlidesPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * pointScale) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
    }

    private struct Line {
        var content: String
        var style: TextStyle?
        var bullet: Bullet?
        var alignment: GSlidesSchema.Alignment?
    }

    private var lines: [Line] {
        (text.textElements ?? []).compactMap { element in
            guard let run = element.textRun, let content = run.content else { return nil }
            let trimmed = content.hasSuffix("\n") ? String(content.dropLast()) : content
            guard !trimmed.isEmpty else { return nil }
            return Line(
                content: trimmed,
                style: run.style,
                bullet: element.paragraphMarker?.bullet,
                alignment: element.paragraphMarker?.style?.alignment
            )
        }
    }

    @ViewBuilder
    private func lineView(_ line: Line) -> some View {
        let fontSize = (line.style?.fontSize?.pointMagnitude
            ?? PlaceholderTypography.defaultFontSize(for: placeholderType)) * pointScale
        let base = line.bullet.map { "\($0.glyph ?? "•")  \(line.content)" } ?? line.content
        Text(base)
            .font(.system(size: fontSize, weight: line.style?.bold == true ? .bold : weightDefault))
            .italic(line.style?.italic == true)
            .underline(line.style?.underline == true)
            .strikethrough(line.style?.strikethrough == true)
            .foregroundStyle(palette.color(line.style?.foregroundColor) ?? .primary)
            .frame(maxWidth: .infinity, alignment: frameAlignment(line.alignment))
            .minimumScaleFactor(0.3)
    }

    private var weightDefault: Font.Weight {
        switch placeholderType {
        case .some(.centeredTitle), .some(.title): .semibold
        default: .regular
        }
    }

    private func frameAlignment(_ alignment: GSlidesSchema.Alignment?) -> SwiftUI.Alignment {
        switch alignment {
        case .some(.center): .center
        case .some(.end): .trailing
        default: placeholderType == .centeredTitle ? .center : .leading
        }
    }
}
