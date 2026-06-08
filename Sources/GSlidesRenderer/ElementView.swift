import GSlidesLayout
import GSlidesSchema
import SwiftUI

struct ElementView: View {
    var element: PageElement
    var pointScale: Double
    var palette: GSlidesPalette

    var body: some View {
        switch element.kind {
        case .shape(let shape):
            shapeView(shape)
        case .image(let image):
            imageView(image)
        case .line(let line):
            lineView(line)
        case .table(let table):
            TableElementView(table: table, pointScale: pointScale, palette: palette)
        case .elementGroup(let group):
            // Children of a group keep page coordinates in the profile.
            ForEach(group.children ?? [], id: \.objectId) { child in
                ElementView(element: child, pointScale: pointScale, palette: palette)
            }
        case .video(let video):
            videoView(video)
        case .sheetsChart(let chart):
            chartView(chart)
        case .wordArt(let wordArt):
            wordArtView(wordArt)
        case .speakerSpotlight:
            placeholderBox(systemImage: "person.crop.rectangle")
        case .unknown:
            unknownView
        }
    }

    @ViewBuilder
    private func videoView(_ video: Video) -> some View {
        // Static deck rendering: show the thumbnail with a play affordance (no inline playback).
        ZStack {
            if let url = video.url.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    if case .success(let loaded) = phase { loaded.resizable().scaledToFit() } else { Color.black.opacity(0.85) }
                }
            } else {
                Color.black.opacity(0.85)
            }
            SwiftUI.Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 3)
        }
    }

    @ViewBuilder
    private func chartView(_ chart: SheetsChart) -> some View {
        if let url = chart.contentUrl.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                if case .success(let loaded) = phase { loaded.resizable().scaledToFit() } else { placeholderBox(systemImage: "chart.bar") }
            }
        } else {
            placeholderBox(systemImage: "chart.bar")
        }
    }

    private func wordArtView(_ wordArt: WordArt) -> some View {
        Text(wordArt.renderedText ?? "")
            .font(.system(size: 24 * pointScale, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func shapeView(_ shape: GSlidesSchema.Shape) -> some View {
        let fill = palette.color(shape.shapeProperties?.shapeBackgroundFill?.solidFill)
        let outline = shape.shapeProperties?.outline
        ZStack {
            if fill != nil || outline != nil {
                shapeStyle(shape.shapeType)
                    .fill(fill ?? .clear)
                    .strokeBorder(
                        palette.color(outline?.outlineFill?.solidFill) ?? .clear,
                        lineWidth: (outline?.weight?.pointMagnitude ?? 0) * pointScale
                    )
            }
            if let text = shape.text {
                TextContentView(
                    text: text,
                    placeholderType: shape.placeholder?.type,
                    pointScale: pointScale,
                    palette: palette
                )
                .padding(4 * pointScale)
            }
        }
    }

    private func shapeStyle(_ type: ShapeType?) -> AnyInsettableShape {
        switch type {
        case .some(.ellipse): AnyInsettableShape(Ellipse())
        case .some(.roundRectangle): AnyInsettableShape(RoundedRectangle(cornerRadius: 8))
        default: AnyInsettableShape(Rectangle())
        }
    }

    @ViewBuilder
    private func imageView(_ image: GSlidesSchema.Image) -> some View {
        if let url = (image.contentUrl ?? image.sourceUrl).flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loaded):
                    loaded.resizable().scaledToFit()
                case .failure:
                    placeholderBox(systemImage: "photo")
                default:
                    ProgressView()
                }
            }
        } else {
            placeholderBox(systemImage: "photo")
        }
    }

    private func lineView(_ line: GSlidesSchema.Line) -> some View {
        Rectangle()
            .fill(palette.color(line.lineProperties?.lineFill?.solidFill) ?? .secondary)
            .frame(height: max(1, (line.lineProperties?.weight?.pointMagnitude ?? 1) * pointScale))
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private var unknownView: some View {
        placeholderBox(systemImage: "questionmark.square.dashed")
    }

    private func placeholderBox(systemImage: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
            .overlay(SwiftUI.Image(systemName: systemImage).foregroundStyle(.secondary))
    }
}

struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: @Sendable (CGRect, CGFloat) -> Path

    init(_ shape: some InsettableShape) {
        pathBuilder = { rect, inset in
            shape.inset(by: inset).path(in: rect)
        }
    }

    private var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect, insetAmount)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct TableElementView: View {
    var table: GSlidesSchema.Table
    var pointScale: Double
    var palette: GSlidesPalette

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(Array((table.tableRows ?? []).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array((row.tableCells ?? []).enumerated()), id: \.offset) { _, cell in
                        cellView(cell)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: TableCell) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5)
            if let text = cell.text {
                TextContentView(text: text, placeholderType: nil, pointScale: pointScale, palette: palette)
                    .padding(3 * pointScale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
