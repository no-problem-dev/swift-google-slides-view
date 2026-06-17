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
            groupView(group)
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

    /// A group positions its children inside its own frame: each child's page-space frame is offset
    /// by the group's origin and scaled to the group's display size (children keep page coordinates
    /// in the profile).
    private func groupView(_ group: GSlidesSchema.Group) -> some View {
        let groupFrame = PageGeometry.frame(of: element)
        return GeometryReader { geo in
            let scale = groupFrame.map { $0.width > 0 ? geo.size.width / $0.width : 1 } ?? 1
            ZStack(alignment: .topLeading) {
                ForEach(group.children ?? [], id: \.objectId) { child in
                    if let cf = PageGeometry.frame(of: child), let gf = groupFrame {
                        ElementView(element: child, pointScale: pointScale, palette: palette)
                            .frame(width: cf.width * scale, height: cf.height * scale)
                            .offset(x: (cf.minX - gf.minX) * scale, y: (cf.minY - gf.minY) * scale)
                    } else {
                        ElementView(element: child, pointScale: pointScale, palette: palette)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func videoView(_ video: Video) -> some View {
        // Static presentation rendering: show the thumbnail with a play affordance (no inline playback).
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
                    .fill(fill ?? .clear, style: FillStyle(eoFill: true))  // even-odd enables holes (donut, frame)
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
                // Honor the shape's vertical content alignment for text. A fill-less text box otherwise
                // collapses to its intrinsic height and the outer positioning frame centers it — making
                // `contentAlignment` a no-op (top/bottom-aligned bodies floated to the box center). Filling
                // the frame lets `.top`/`.bottom` actually pin; `.middle`/default stays centered as before.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment(props?.contentAlignment))
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
        gslidesDashPattern(style, scale: scale)
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
        case .some(.heart): AnyInsettableShape(path: ShapeGeometry.heart)
        case .some(.cloud): AnyInsettableShape(path: ShapeGeometry.cloud)
        case .some(.parallelogram): AnyInsettableShape(path: ShapeGeometry.parallelogram)
        case .some(.trapezoid): AnyInsettableShape(path: ShapeGeometry.trapezoid)
        case .some(.rightTriangle): AnyInsettableShape(path: ShapeGeometry.rightTriangle)
        case .some(.plus): AnyInsettableShape(path: ShapeGeometry.plus)
        case .some(.homePlate): AnyInsettableShape(path: { ShapeGeometry.homePlate($0, notched: false) })
        case .some(.chevron): AnyInsettableShape(path: { ShapeGeometry.homePlate($0, notched: true) })
        case .some(.donut): AnyInsettableShape(path: ShapeGeometry.donut)
        case .some(.frame): AnyInsettableShape(path: ShapeGeometry.frame)
        case .some(.halfFrame): AnyInsettableShape(path: ShapeGeometry.halfFrame)
        case .some(.pie): AnyInsettableShape(path: ShapeGeometry.pie)
        case .some(.chord): AnyInsettableShape(path: ShapeGeometry.chord)
        case .some(.teardrop): AnyInsettableShape(path: ShapeGeometry.teardrop)
        case .some(.bevel): AnyInsettableShape(path: ShapeGeometry.bevel)
        case .some(.cube): AnyInsettableShape(path: ShapeGeometry.cube)
        case .some(.foldedCorner): AnyInsettableShape(path: ShapeGeometry.foldedCorner)
        case .some(.diagonalStripe): AnyInsettableShape(path: ShapeGeometry.diagonalStripe)
        case .some(.lightningBolt): AnyInsettableShape(path: ShapeGeometry.lightningBolt)
        case .some(.mathPlus): AnyInsettableShape(path: ShapeGeometry.mathPlus)
        case .some(.mathMinus): AnyInsettableShape(path: ShapeGeometry.mathMinus)
        case .some(.mathMultiply): AnyInsettableShape(path: ShapeGeometry.mathMultiply)
        case .some(.mathDivide): AnyInsettableShape(path: ShapeGeometry.mathDivide)
        case .some(.mathEqual): AnyInsettableShape(path: ShapeGeometry.mathEqual)
        default:
            if let points = starPoints(type) {
                AnyInsettableShape(path: { ShapeGeometry.star($0, points: points) })
            } else if let sides = polygonSides(type) {
                AnyInsettableShape(path: { ShapeGeometry.regularPolygon($0, sides: sides) })
            } else {
                AnyInsettableShape(Rectangle())
            }
        }
    }

    /// STAR_N → N points (4…32).
    private func starPoints(_ type: ShapeType?) -> Int? {
        guard let raw = type?.rawValue, raw.hasPrefix("STAR_") else { return nil }
        return Int(raw.dropFirst("STAR_".count))
    }

    private func polygonSides(_ type: ShapeType?) -> Int? {
        switch type {
        case .some(.pentagon): 5
        case .some(.hexagon): 6
        case .some(.heptagon): 7
        case .some(.octagon): 8
        case .some(.decagon): 10
        case .some(.dodecagon): 12
        default: nil
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
        let category = lineCategory(line)
        // A flip (negative scale, normalized away by PageGeometry) chooses the other diagonal: a
        // vertical flip makes the line rise (bottom-left → top-right) instead of fall — what a line
        // chart's ascending segment needs. Positive scales keep the historical top-left → bottom-right.
        let vFlip = (element.transform?.scaleY ?? 1) < 0
        let hFlip = (element.transform?.scaleX ?? 1) < 0
        return GeometryReader { geo in
            let start = CGPoint(x: hFlip ? geo.size.width : 0, y: vFlip ? geo.size.height : 0)
            let end = CGPoint(x: hFlip ? 0 : geo.size.width, y: vFlip ? 0 : geo.size.height)
            // For BENT/CURVED connectors the tangent at the end is horizontal (elbow/curve arrive
            // sideways); STRAIGHT arrives along the diagonal.
            let endFrom = category == .straight ? start : CGPoint(x: 0, y: end.y)
            let startFrom = category == .straight ? end : CGPoint(x: end.x, y: start.y)
            ZStack {
                linePath(category, start: start, end: end)
                    .stroke(color, style: StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round, dash: dashPattern(props?.dashStyle, scale: pointScale)))
                if hasArrow(props?.endArrow) { arrowHead(tip: end, from: endFrom, size: weight * 4, color: color) }
                if hasArrow(props?.startArrow) { arrowHead(tip: start, from: startFrom, size: weight * 4, color: color) }
            }
        }
    }

    /// Effective line category: explicit `lineCategory`, else inferred from a BENT_/CURVED_ `lineType`.
    private func lineCategory(_ line: GSlidesSchema.Line) -> LineCategory {
        if let category = line.lineCategory, category != .unspecified { return category }
        let raw = line.lineType?.rawValue ?? ""
        if raw.hasPrefix("BENT") { return .bent }
        if raw.hasPrefix("CURVED") { return .curved }
        return .straight
    }

    private func linePath(_ category: LineCategory, start: CGPoint, end: CGPoint) -> Path {
        Path { p in
            p.move(to: start)
            switch category {
            case .bent:
                // an elbow: horizontal to mid-x, then vertical, then horizontal to the end
                let midX = (start.x + end.x) / 2
                p.addLine(to: CGPoint(x: midX, y: start.y))
                p.addLine(to: CGPoint(x: midX, y: end.y))
                p.addLine(to: end)
            case .curved:
                p.addQuadCurve(to: end, control: CGPoint(x: end.x, y: start.y))
            default:
                p.addLine(to: end)
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
            content.grayscale(0.6).colorMultiply(palette.presentation.onBackground)
        case .some(let name) where name.rawValue.hasPrefix("LIGHT"):
            content.grayscale(0.6).colorMultiply(palette.presentation.background)
        case .some(.custom) where props?.recolor?.recolorStops?.isEmpty == false:
            // Custom duotone: grayscale tinted toward a representative stop color (approximation).
            content.grayscale(1).colorMultiply(customRecolorTint ?? .white)
        default:
            content
        }
    }

    /// The brightest custom recolor stop, used as the duotone highlight tint.
    private var customRecolorTint: Color? {
        let stops = props?.recolor?.recolorStops ?? []
        let stop = stops.max { ($0.position ?? 0) < ($1.position ?? 0) } ?? stops.first
        return stop.flatMap { palette.color($0.color) }
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

    /// An N-pointed star (STAR_4 … STAR_32).
    static func star(_ r: CGRect, points: Int) -> Path {
        let center = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * (points <= 5 ? 0.4 : 0.6)
        return Path { p in
            for i in 0 ..< (points * 2) {
                let radius = i.isMultiple(of: 2) ? outer : inner
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }

    /// A regular N-gon (PENTAGON … DODECAGON), flat-ish top.
    static func regularPolygon(_ r: CGRect, sides: Int) -> Path {
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        return Path { p in
            for i in 0 ..< sides {
                let angle = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(sides)
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }

    static func parallelogram(_ r: CGRect) -> Path {
        let slant = r.width * 0.25
        return Path { p in
            p.move(to: CGPoint(x: r.minX + slant, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - slant, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }

    static func trapezoid(_ r: CGRect) -> Path {
        let inset = r.width * 0.22
        return Path { p in
            p.move(to: CGPoint(x: r.minX + inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }

    static func rightTriangle(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
        }
    }

    /// A Greek cross as a single 12-point polygon (`arm` = fraction of each side left as the gap).
    static func cross(_ r: CGRect, arm: CGFloat, rotated: Bool = false) -> Path {
        let tx = r.width * arm, ty = r.height * arm
        let path = Path { p in
            p.move(to: CGPoint(x: r.minX + tx, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - tx, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - tx, y: r.minY + ty))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + ty))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - ty))
            p.addLine(to: CGPoint(x: r.maxX - tx, y: r.maxY - ty))
            p.addLine(to: CGPoint(x: r.maxX - tx, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + tx, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + tx, y: r.maxY - ty))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - ty))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + ty))
            p.addLine(to: CGPoint(x: r.minX + tx, y: r.minY + ty))
            p.closeSubpath()
        }
        guard rotated else { return path }
        let t = CGAffineTransform(translationX: r.midX, y: r.midY).rotated(by: .pi / 4).translatedBy(x: -r.midX, y: -r.midY)
        return path.applying(t)
    }

    static func plus(_ r: CGRect) -> Path { cross(r, arm: 0.33) }

    // MARK: math symbols (thin bars; subpaths never overlap so even-odd fills them solid)

    private static func hBar(_ r: CGRect, yFrac: CGFloat, hFrac: CGFloat = 0.13, wFrac: CGFloat = 0.62) -> CGRect {
        CGRect(x: r.midX - r.width * wFrac / 2, y: r.minY + r.height * yFrac - r.height * hFrac / 2,
               width: r.width * wFrac, height: r.height * hFrac)
    }

    static func mathMinus(_ r: CGRect) -> Path { Path { $0.addRect(hBar(r, yFrac: 0.5)) } }
    static func mathEqual(_ r: CGRect) -> Path { Path { $0.addRect(hBar(r, yFrac: 0.38)); $0.addRect(hBar(r, yFrac: 0.62)) } }
    static func mathPlus(_ r: CGRect) -> Path { cross(r, arm: 0.42) }
    static func mathMultiply(_ r: CGRect) -> Path { cross(r, arm: 0.42, rotated: true) }
    static func mathDivide(_ r: CGRect) -> Path {
        let dot = r.width * 0.12
        return Path { p in
            p.addRect(hBar(r, yFrac: 0.5))
            p.addEllipse(in: CGRect(x: r.midX - dot / 2, y: r.minY + r.height * 0.22 - dot / 2, width: dot, height: dot))
            p.addEllipse(in: CGRect(x: r.midX - dot / 2, y: r.minY + r.height * 0.78 - dot / 2, width: dot, height: dot))
        }
    }

    // MARK: misc

    /// A ring — outer + inner ellipse, even-odd fill makes the hole.
    static func donut(_ r: CGRect) -> Path {
        Path { p in
            p.addEllipse(in: r)
            p.addEllipse(in: r.insetBy(dx: r.width * 0.25, dy: r.height * 0.25))
        }
    }

    /// A rectangular border — outer + inner rect, even-odd hole.
    static func frame(_ r: CGRect) -> Path {
        Path { p in
            p.addRect(r)
            p.addRect(r.insetBy(dx: r.width * 0.15, dy: r.height * 0.15))
        }
    }

    /// An L-shaped corner border.
    static func halfFrame(_ r: CGRect) -> Path {
        let t = min(r.width, r.height) * 0.18
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
            p.addLine(to: CGPoint(x: r.minX + t, y: r.minY + t))
            p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }

    /// A pie wedge (about three-quarters).
    static func pie(_ r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        return Path { p in
            p.move(to: c)
            p.addArc(center: c, radius: min(r.width, r.height) / 2, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
        }
    }

    /// A circular segment cut by a horizontal chord.
    static func chord(_ r: CGRect) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) / 2,
                     startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            p.closeSubpath()
        }
    }

    /// A circle whose top-right quadrant is replaced by a right-angle point (water-drop).
    static func teardrop(_ r: CGRect) -> Path {
        let rad = min(r.width, r.height) / 2
        let c = CGPoint(x: r.minX + rad, y: r.maxY - rad)
        return Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - rad))                                 // 12 o'clock
            p.addArc(center: c, radius: rad, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: true) // long way (through 9,6) to 3 o'clock
            p.addLine(to: CGPoint(x: c.x + rad, y: c.y - rad))                         // the point (corner)
            p.closeSubpath()
        }
    }

    /// A rectangle with chamfered (cut) corners.
    static func bevel(_ r: CGRect) -> Path {
        let c = min(r.width, r.height) * 0.2
        return Path { p in
            p.move(to: CGPoint(x: r.minX + c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
            p.closeSubpath()
        }
    }

    /// A 3D box (front + top + right faces; non-overlapping so even-odd fills solid).
    static func cube(_ r: CGRect) -> Path {
        let d = min(r.width, r.height) * 0.25
        return Path { p in
            p.addRect(CGRect(x: r.minX, y: r.minY + d, width: r.width - d, height: r.height - d))   // front
            p.move(to: CGPoint(x: r.minX, y: r.minY + d))                                            // top
            p.addLine(to: CGPoint(x: r.minX + d, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - d, y: r.minY + d))
            p.closeSubpath()
            p.move(to: CGPoint(x: r.maxX - d, y: r.minY + d))                                        // right
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - d))
            p.addLine(to: CGPoint(x: r.maxX - d, y: r.maxY))
            p.closeSubpath()
        }
    }

    /// A rectangle with a folded bottom-right corner.
    static func foldedCorner(_ r: CGRect) -> Path {
        let f = min(r.width, r.height) * 0.25
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - f))
            p.addLine(to: CGPoint(x: r.maxX - f, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
            p.move(to: CGPoint(x: r.maxX - f, y: r.maxY))                                            // the fold
            p.addLine(to: CGPoint(x: r.maxX - f, y: r.maxY - f))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - f))
        }
    }

    /// A diagonal band across the box.
    static func diagonalStripe(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.closeSubpath()
        }
    }

    static func lightningBolt(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX + w * 0.55, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.45))
            p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.45))
            p.addLine(to: CGPoint(x: r.minX + w * 0.3, y: r.minY + h))
            p.addLine(to: CGPoint(x: r.minX + w * 0.75, y: r.minY + h * 0.4))
            p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.4))
            p.addLine(to: CGPoint(x: r.minX + w * 0.7, y: r.minY))
            p.closeSubpath()
        }
    }

    /// A pentagon arrow / home plate (HOME_PLATE) and CHEVRON share a pointed-right outline.
    static func homePlate(_ r: CGRect, notched: Bool) -> Path {
        let point = r.width * 0.3
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - point, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX - point, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            if notched { p.addLine(to: CGPoint(x: r.minX + point, y: r.midY)) }
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

/// Profile `DashStyle` → SwiftUI stroke dash pattern (shared by shapes, lines, and table borders).
func gslidesDashPattern(_ style: DashStyle?, scale: Double) -> [CGFloat] {
    switch style {
    case .some(.dot): [1 * scale, 3 * scale]
    case .some(.dash), .some(.longDash): [6 * scale, 4 * scale]
    case .some(.dashDot), .some(.longDashDot): [6 * scale, 3 * scale, 1 * scale, 3 * scale]
    default: []
    }
}

/// A table layout engine: proportional column widths / row heights, merged cells (rowSpan /
/// columnSpan), per-cell background + content alignment, and per-edge borders from the table's
/// horizontal/vertical border rows (default grid lines when the table declares none).
struct TableElementView: View {
    var table: GSlidesSchema.Table
    var pointScale: Double
    var palette: GSlidesPalette

    private var tableRows: [GSlidesSchema.TableRow] { table.tableRows ?? [] }
    private var rowCount: Int { table.rows ?? tableRows.count }
    private var columnCount: Int { table.columns ?? (tableRows.map { $0.tableCells?.count ?? 0 }.max() ?? 0) }

    private struct Placed: Identifiable {
        let id: String
        let r, c, rowSpan, columnSpan: Int
        let cell: TableCell
    }

    /// Head cells (skipping positions covered by a span), with their span.
    private var placedCells: [Placed] {
        var covered = Set<[Int]>()
        var result: [Placed] = []
        for (r, row) in tableRows.enumerated() {
            for (c, cell) in (row.tableCells ?? []).enumerated() where !covered.contains([r, c]) {
                let rs = max(1, cell.rowSpan ?? 1), cs = max(1, cell.columnSpan ?? 1)
                if rs > 1 || cs > 1 {
                    for dr in 0 ..< rs { for dc in 0 ..< cs where dr != 0 || dc != 0 { covered.insert([r + dr, c + dc]) } }
                }
                result.append(Placed(id: "\(r)-\(c)", r: r, c: c, rowSpan: rs, columnSpan: cs, cell: cell))
            }
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let xs = edges(spans: columnSpans, total: geo.size.width)
            let ys = edges(spans: rowSpans, total: geo.size.height)
            ZStack(alignment: .topLeading) {
                ForEach(placedCells) { placed in
                    let x0 = xs[placed.c], y0 = ys[placed.r]
                    let w = xs[min(placed.c + placed.columnSpan, columnCount)] - x0
                    let h = ys[min(placed.r + placed.rowSpan, rowCount)] - y0
                    cellView(placed.cell)
                        .frame(width: w, height: h)
                        .overlay(cellBorders(placed, xs: xs, ys: ys))
                        .offset(x: x0, y: y0)
                }
            }
        }
    }

    // MARK: track sizes

    private var columnSpans: [CGFloat] {
        guard let cols = table.tableColumns, cols.count == columnCount else { return Array(repeating: 1, count: columnCount) }
        return cols.map { CGFloat($0.columnWidth?.magnitude ?? 0) }
    }

    private var rowSpans: [CGFloat] {
        let heights = tableRows.map { CGFloat($0.rowHeight?.magnitude ?? 0) }
        return heights.contains(where: { $0 > 0 }) ? heights : Array(repeating: 1, count: rowCount)
    }

    /// Cumulative edge offsets (count+1) from per-track weights, scaled to `total`.
    private func edges(spans: [CGFloat], total: CGFloat) -> [CGFloat] {
        let weights = spans.contains(where: { $0 > 0 }) ? spans : Array(repeating: 1, count: spans.count)
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return [0, total] }
        var offsets: [CGFloat] = [0]
        for w in weights { offsets.append(offsets.last! + total * w / sum) }
        return offsets
    }

    // MARK: cell content

    @ViewBuilder
    private func cellView(_ cell: TableCell) -> some View {
        let fill = palette.color(cell.tableCellProperties?.tableCellBackgroundFill?.solidFill)
        ZStack(alignment: cellAlignment(cell.tableCellProperties?.contentAlignment)) {
            (fill ?? .clear)
            if let text = cell.text {
                TextContentView(text: text, placeholderType: nil, pointScale: pointScale, palette: palette)
                    .padding(3 * pointScale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cellAlignment(_ value: ContentAlignment?) -> SwiftUI.Alignment {
        switch value {
        case .some(.middle): .leading
        case .some(.bottom): .bottomLeading
        default: .topLeading
        }
    }

    // MARK: borders

    /// The four edges of a (possibly merged) cell, each stroked with its border properties (or a
    /// default thin line). Drawn in the cell's local coordinate space.
    private func cellBorders(_ placed: Placed, xs: [CGFloat], ys: [CGFloat]) -> some View {
        let w = xs[min(placed.c + placed.columnSpan, columnCount)] - xs[placed.c]
        let h = ys[min(placed.r + placed.rowSpan, rowCount)] - ys[placed.r]
        let endC = placed.c + placed.columnSpan, endR = placed.r + placed.rowSpan
        return ZStack {
            edge(hBorder(placed.r, placed.c), from: CGPoint(x: 0, y: 0), to: CGPoint(x: w, y: 0))       // top
            edge(hBorder(endR, placed.c), from: CGPoint(x: 0, y: h), to: CGPoint(x: w, y: h))           // bottom
            edge(vBorder(placed.r, placed.c), from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: h))       // left
            edge(vBorder(placed.r, endC), from: CGPoint(x: w, y: 0), to: CGPoint(x: w, y: h))           // right
        }
    }

    private func hBorder(_ r: Int, _ c: Int) -> TableBorderProperties? {
        guard let rows = table.horizontalBorderRows, r < rows.count else { return nil }
        let cells = rows[r].tableBorderCells ?? []
        return c < cells.count ? cells[c].tableBorderProperties : nil
    }

    private func vBorder(_ r: Int, _ c: Int) -> TableBorderProperties? {
        guard let rows = table.verticalBorderRows, r < rows.count else { return nil }
        let cells = rows[r].tableBorderCells ?? []
        return c < cells.count ? cells[c].tableBorderProperties : nil
    }

    private func edge(_ border: TableBorderProperties?, from: CGPoint, to: CGPoint) -> some View {
        let color = palette.color(border?.tableBorderFill?.solidFill) ?? palette.presentation.outline.opacity(0.5)
        let width = CGFloat(border?.weight?.pointMagnitude ?? 0.75) * pointScale
        return Path { p in p.move(to: from); p.addLine(to: to) }
            .stroke(color, style: StrokeStyle(lineWidth: width, dash: gslidesDashPattern(border?.dashStyle, scale: pointScale)))
    }
}
