import GSlidesLayout
import GSlidesSchema
import SwiftUI

struct ElementView: View {
    @Environment(\.gslidesImageProvider) private var imageProvider
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
            if let provided = imageProvider?.image(for: url) {
                provided.resizable().scaledToFit()
            } else {
                AsyncImage(url: url) { phase in
                    if case .success(let loaded) = phase { loaded.resizable().scaledToFit() } else { placeholderBox(systemImage: "chart.bar") }
                }
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
        let props = shape.shapeProperties
        let fill = palette.color(props?.shapeBackgroundFill?.solidFill)
        let outline = props?.outline
        ZStack(alignment: contentAlignment(props?.contentAlignment)) {
            if fill != nil || outline != nil {
                shapeStyle(shape.shapeType)
                    .fill(fill ?? .clear)
                    .strokeBorder(
                        palette.color(outline?.outlineFill?.solidFill) ?? .clear,
                        style: StrokeStyle(
                            lineWidth: (outline?.weight?.pointMagnitude ?? 0) * pointScale,
                            dash: dashPattern(outline?.dashStyle, scale: pointScale)
                        )
                    )
                    .modifier(ShadowModifier(shadow: props?.shadow, palette: palette, scale: pointScale))
            }
            if let text = shape.text {
                let autofit = props?.autofit
                let scale = autofit?.autofitType == .textAutofit ? (autofit?.fontScale ?? 1) : 1
                TextContentView(
                    text: text,
                    placeholderType: shape.placeholder?.type,
                    pointScale: pointScale,
                    palette: palette,
                    fontScale: scale > 0 ? scale : 1,
                    lineSpacingReduction: autofit?.autofitType == .textAutofit ? (autofit?.lineSpacingReduction ?? 0) : 0
                )
                .padding(4 * pointScale)
            }
        }
    }

    private func contentAlignment(_ value: ContentAlignment?) -> SwiftUI.Alignment {
        switch value {
        case .some(.top): .top
        case .some(.bottom): .bottom
        case .some(.middle): .center
        default: .center
        }
    }

    private func dashPattern(_ style: DashStyle?, scale: Double) -> [CGFloat] {
        switch style {
        case .some(.dot): [1 * scale, 3 * scale]
        case .some(.dash), .some(.longDash): [6 * scale, 4 * scale]
        case .some(.dashDot), .some(.longDashDot): [6 * scale, 3 * scale, 1 * scale, 3 * scale]
        default: []
        }
    }

    private func shapeStyle(_ type: ShapeType?) -> AnyInsettableShape {
        switch type {
        case .some(.ellipse): AnyInsettableShape(Ellipse())
        case .some(.roundRectangle): AnyInsettableShape(RoundedRectangle(cornerRadius: 8))
        case .some(.triangle): AnyInsettableShape(path: ShapeGeometry.triangle)
        case .some(.diamond): AnyInsettableShape(path: ShapeGeometry.diamond)
        case .some(.rightArrow): AnyInsettableShape(path: { ShapeGeometry.arrow($0, .right) })
        case .some(.leftArrow): AnyInsettableShape(path: { ShapeGeometry.arrow($0, .left) })
        case .some(.upArrow): AnyInsettableShape(path: { ShapeGeometry.arrow($0, .up) })
        case .some(.downArrow): AnyInsettableShape(path: { ShapeGeometry.arrow($0, .down) })
        case .some(.star5): AnyInsettableShape(path: ShapeGeometry.star5)
        case .some(.heart): AnyInsettableShape(path: ShapeGeometry.heart)
        case .some(.cloud): AnyInsettableShape(path: ShapeGeometry.cloud)
        default: AnyInsettableShape(Rectangle())
        }
    }

    @ViewBuilder
    private func imageView(_ image: GSlidesSchema.Image) -> some View {
        if let url = (image.contentUrl ?? image.sourceUrl).flatMap(URL.init(string:)) {
            if let provided = imageProvider?.image(for: url) {
                styledImage(provided, image.imageProperties)
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loaded):
                        styledImage(loaded, image.imageProperties)
                    case .failure:
                        placeholderBox(systemImage: "photo")
                    default:
                        ProgressView()
                    }
                }
            }
        } else {
            placeholderBox(systemImage: "photo")
        }
    }

    /// Applies the profile's `imageProperties` — crop, then color adjustments, outline and shadow.
    private func styledImage(_ img: SwiftUI.Image, _ props: ImageProperties?) -> some View {
        cropped(img, props?.cropProperties)
            .modifier(ImageEffectsModifier(props: props, palette: palette, scale: pointScale))
    }

    /// Crop offsets are fractions of each edge: the visible region fills the element box. With no
    /// crop the image is fit (letterboxed) as before.
    @ViewBuilder
    private func cropped(_ img: SwiftUI.Image, _ crop: CropProperties?) -> some View {
        if let crop, (crop.leftOffset ?? 0) + (crop.rightOffset ?? 0) + (crop.topOffset ?? 0) + (crop.bottomOffset ?? 0) > 0 {
            GeometryReader { geo in
                let l = crop.leftOffset ?? 0, r = crop.rightOffset ?? 0
                let t = crop.topOffset ?? 0, b = crop.bottomOffset ?? 0
                let visW = max(0.01, 1 - l - r), visH = max(0.01, 1 - t - b)
                let fullW = geo.size.width / visW, fullH = geo.size.height / visH
                img.resizable()
                    .frame(width: fullW, height: fullH)
                    .offset(x: -l * fullW, y: -t * fullH)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .clipped()
            }
        } else {
            img.resizable().scaledToFit()
        }
    }

    /// Draws the line along its bounding box's diagonal (top-left → bottom-right), so a short-and-wide
    /// box reads horizontal, a tall-and-narrow box vertical, and a square box diagonal — honoring the
    /// element geometry instead of forcing a horizontal bar. Arrowheads are drawn where present.
    private func lineView(_ line: GSlidesSchema.Line) -> some View {
        let props = line.lineProperties
        let color = palette.color(props?.lineFill?.solidFill) ?? .secondary
        let weight = max(1, (props?.weight?.pointMagnitude ?? 1) * pointScale)
        return GeometryReader { geo in
            let start = CGPoint(x: 0, y: 0)
            let end = CGPoint(x: geo.size.width, y: geo.size.height)
            ZStack {
                Path { p in p.move(to: start); p.addLine(to: end) }
                    .stroke(color, style: StrokeStyle(lineWidth: weight, lineCap: .round, dash: dashPattern(props?.dashStyle, scale: pointScale)))
                if hasArrow(props?.endArrow) { arrowHead(tip: end, from: start, size: weight * 4, color: color) }
                if hasArrow(props?.startArrow) { arrowHead(tip: start, from: end, size: weight * 4, color: color) }
            }
        }
    }

    private func hasArrow(_ style: ArrowStyle?) -> Bool {
        guard let style else { return false }
        return style != .none && style != .unspecified
    }

    /// A filled triangular arrowhead at `tip`, pointing away from `from`. (All arrow variants are
    /// approximated as a filled triangle.)
    private func arrowHead(tip: CGPoint, from: CGPoint, size: CGFloat, color: Color) -> some View {
        let angle = atan2(tip.y - from.y, tip.x - from.x)
        let wing = CGFloat.pi / 7
        let p1 = CGPoint(x: tip.x - size * cos(angle - wing), y: tip.y - size * sin(angle - wing))
        let p2 = CGPoint(x: tip.x - size * cos(angle + wing), y: tip.y - size * sin(angle + wing))
        return Path { p in
            p.move(to: tip); p.addLine(to: p1); p.addLine(to: p2); p.closeSubpath()
        }.fill(color)
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

/// Applies a profile `ImageProperties`' color adjustments (recolor, brightness, contrast,
/// transparency), then outline and shadow. Absent/zero values are no-ops, so plain images render
/// unchanged. Brightness/transparency map 1:1; profile contrast (−1…1, 0 = normal) → SwiftUI's
/// (1 = normal) as `1 + contrast`.
struct ImageEffectsModifier: ViewModifier {
    var props: ImageProperties?
    var palette: GSlidesPalette
    var scale: Double

    func body(content: Content) -> some View {
        recolored(content)
            .brightness(props?.brightness ?? 0)
            .contrast(1 + (props?.contrast ?? 0))
            .opacity(1 - (props?.transparency ?? 0))
            .overlay(outline)
            .modifier(ShadowModifier(shadow: props?.shadow, palette: palette, scale: scale))
    }

    @ViewBuilder
    private func recolored(_ content: Content) -> some View {
        switch props?.recolor?.name {
        case .some(.grayscale):
            content.grayscale(1)
        case .some(.negative):
            content.colorInvert()
        case .some(.sepia):
            content.grayscale(1).colorMultiply(Color(red: 0.76, green: 0.6, blue: 0.42))
        case .some(let name) where name.rawValue.hasPrefix("DARK"):
            content.grayscale(0.6).colorMultiply(palette.deck.onBackground)
        case .some(let name) where name.rawValue.hasPrefix("LIGHT"):
            content.grayscale(0.6).colorMultiply(palette.deck.background)
        default:
            content
        }
    }

    @ViewBuilder
    private var outline: some View {
        if let outline = props?.outline, outline.propertyState != .notRendered,
           let color = palette.color(outline.outlineFill?.solidFill) {
            Rectangle().stroke(
                color,
                style: StrokeStyle(lineWidth: (outline.weight?.pointMagnitude ?? 1) * scale)
            )
        }
    }
}

/// Renders a profile `Shadow` as a SwiftUI shadow (OUTER only; the profile's other states are no-ops).
struct ShadowModifier: ViewModifier {
    var shadow: Shadow?
    var palette: GSlidesPalette
    var scale: Double

    func body(content: Content) -> some View {
        if let shadow, shadow.type == .outer, shadow.propertyState != .notRendered {
            let color = (palette.color(shadow.color) ?? .black).opacity(shadow.alpha ?? 0.4)
            let radius = (shadow.blurRadius?.pointMagnitude ?? 4) * scale
            content.shadow(color: color, radius: radius, x: radius * 0.3, y: radius * 0.3)
        } else {
            content
        }
    }
}

struct AnyInsettableShape: InsettableShape {
    private let pathBuilder: @Sendable (CGRect, CGFloat) -> Path

    init(_ shape: some InsettableShape) {
        pathBuilder = { rect, inset in
            shape.inset(by: inset).path(in: rect)
        }
    }

    /// Builds an arbitrary shape from a rect → Path closure; insetting shrinks the rect (a good
    /// approximation of stroke inset for these polygonal/organic shapes).
    init(path builder: @escaping @Sendable (CGRect) -> Path) {
        pathBuilder = { rect, inset in builder(rect.insetBy(dx: inset, dy: inset)) }
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

/// Path geometry for the profile's non-rectangular `ShapeType`s. Each builds a closed path in a
/// rect; shapes not modeled here fall back to a rectangle.
enum ShapeGeometry {
    enum Direction { case right, left, up, down }

    static func triangle(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }

    static func diamond(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
        }
    }

    /// A block arrow. Built pointing right, then rotated for the other directions.
    static func arrow(_ r: CGRect, _ direction: Direction) -> Path {
        let w = r.width, h = r.height
        let headW = w * 0.45, shaft = h * 0.5
        let top = (h - shaft) / 2
        var p = Path()
        p.move(to: CGPoint(x: 0, y: top))
        p.addLine(to: CGPoint(x: w - headW, y: top))
        p.addLine(to: CGPoint(x: w - headW, y: 0))
        p.addLine(to: CGPoint(x: w, y: h / 2))
        p.addLine(to: CGPoint(x: w - headW, y: h))
        p.addLine(to: CGPoint(x: w - headW, y: top + shaft))
        p.addLine(to: CGPoint(x: 0, y: top + shaft))
        p.closeSubpath()

        let angle: CGFloat = switch direction {
        case .right: 0
        case .down: .pi / 2
        case .left: .pi
        case .up: -.pi / 2
        }
        let transform = CGAffineTransform(translationX: w / 2, y: h / 2)
            .rotated(by: angle)
            .translatedBy(x: -w / 2, y: -h / 2)
        return p.applying(transform).applying(CGAffineTransform(translationX: r.minX, y: r.minY))
    }

    static func star5(_ r: CGRect) -> Path {
        let center = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.4
        return Path { p in
            for i in 0 ..< 10 {
                let radius = i.isMultiple(of: 2) ? outer : inner
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }

    static func heart(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX + w / 2, y: r.minY + h))
            p.addCurve(
                to: CGPoint(x: r.minX, y: r.minY + h * 0.3),
                control1: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.75),
                control2: CGPoint(x: r.minX, y: r.minY + h * 0.6)
            )
            p.addArc(
                center: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.3),
                radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            p.addArc(
                center: CGPoint(x: r.minX + w * 0.75, y: r.minY + h * 0.3),
                radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            p.addCurve(
                to: CGPoint(x: r.minX + w / 2, y: r.minY + h),
                control1: CGPoint(x: r.maxX, y: r.minY + h * 0.6),
                control2: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.75)
            )
            p.closeSubpath()
        }
    }

    /// An approximation: overlapping bumps over a flat base — filled, it reads as a cloud.
    static func cloud(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.addEllipse(in: CGRect(x: r.minX, y: r.minY + h * 0.35, width: w * 0.5, height: h * 0.55))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.2, y: r.minY + h * 0.1, width: w * 0.45, height: h * 0.6))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.45, y: r.minY + h * 0.15, width: w * 0.4, height: h * 0.55))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.5, y: r.minY + h * 0.35, width: w * 0.5, height: h * 0.55))
            p.addRect(CGRect(x: r.minX + w * 0.12, y: r.minY + h * 0.55, width: w * 0.76, height: h * 0.35))
        }
    }
}

struct TableElementView: View {
    var table: GSlidesSchema.Table
    var pointScale: Double
    var palette: GSlidesPalette

    private var rows: [GSlidesSchema.TableRow] { table.tableRows ?? [] }
    private var columnCount: Int {
        table.columns ?? (rows.map { $0.tableCells?.count ?? 0 }.max() ?? 0)
    }

    var body: some View {
        GeometryReader { geo in
            let widths = columnWidths(total: geo.size.width)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(0 ..< columnCount, id: \.self) { column in
                            cellView(cell(row, column))
                                .frame(width: column < widths.count ? widths[column] : nil)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private func cell(_ row: GSlidesSchema.TableRow, _ column: Int) -> TableCell? {
        let cells = row.tableCells ?? []
        return column < cells.count ? cells[column] : nil
    }

    /// Column widths proportional to `tableColumns` (any unit — only the ratio matters); equal split
    /// when the table doesn't declare them.
    private func columnWidths(total: CGFloat) -> [CGFloat] {
        let equal = Array(repeating: total / CGFloat(max(1, columnCount)), count: columnCount)
        guard let columns = table.tableColumns, columns.count == columnCount else { return equal }
        let magnitudes = columns.map { CGFloat($0.columnWidth?.magnitude ?? 0) }
        let sum = magnitudes.reduce(0, +)
        guard sum > 0 else { return equal }
        return magnitudes.map { total * $0 / sum }
    }

    @ViewBuilder
    private func cellView(_ cell: TableCell?) -> some View {
        let fill = palette.color(cell?.tableCellProperties?.tableCellBackgroundFill?.solidFill)
        ZStack(alignment: cellAlignment(cell?.tableCellProperties?.contentAlignment)) {
            (fill ?? .clear)
            if let text = cell?.text {
                TextContentView(text: text, placeholderType: nil, pointScale: pointScale, palette: palette)
                    .padding(3 * pointScale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().stroke(palette.deck.outline.opacity(0.5), lineWidth: 0.75 * pointScale))
    }

    private func cellAlignment(_ value: ContentAlignment?) -> SwiftUI.Alignment {
        switch value {
        case .some(.middle): .leading
        case .some(.bottom): .bottomLeading
        default: .topLeading
        }
    }
}
