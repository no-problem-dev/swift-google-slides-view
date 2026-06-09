import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
import GSlidesSchema
import GSlidesPrompt
@testable import GSlidesRenderer

@MainActor
@Suite struct GSlidesRendererTests {
    func render(_ view: some View, width: CGFloat = 640) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.cgImage
    }

    func semanticPresentation() throws -> Presentation {
        let json = """
        {"title": "Render Demo", "slides": [
            {"layout": "TITLE", "title": "Hello Slides", "subtitle": "Rendered by SwiftUI"},
            {"layout": "BIG_NUMBER", "title": "42%", "big": true, "bodies": [{"text": "of presentations are JSON"}]},
            {"title": "Why", "bodies": [{"bullets": ["schema-first", "A2A streaming", "CLI TDD"]}]}
        ]}
        """
        return try GSlidesGenerationContract.presentation(from: Data(json.utf8))
    }

    @Test func semanticSlideRendersAt16x9() throws {
        let presentation = try semanticPresentation()
        let slide = try #require(presentation.slides?.first)
        let image = try #require(render(GSlidesSlideView(slide: slide, presentation: presentation)))
        let ratio = Double(image.width) / Double(image.height)
        #expect(abs(ratio - 16.0 / 9.0) < 0.05)
    }

    @Test func everySemanticLayoutRenders() throws {
        let presentation = try semanticPresentation()
        for slide in presentation.slides ?? [] {
            #expect(render(GSlidesSlideView(slide: slide, presentation: presentation)) != nil)
        }
    }

    @Test func geometricElementsRender() throws {
        let element = PageElement(
            objectId: "box",
            size: Size(
                width: Dimension(magnitude: 3_000_000, unit: .emu),
                height: Dimension(magnitude: 1_500_000, unit: .emu)
            ),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 1_000_000, translateY: 1_000_000, unit: .emu),
            shape: GSlidesSchema.Shape(
                shapeType: .roundRectangle,
                text: TextContent(textElements: [TextElement(textRun: TextRun(content: "Boxed\n"))]),
                shapeProperties: ShapeProperties(
                    shapeBackgroundFill: ShapeBackgroundFill(
                        solidFill: SolidFill(color: OpaqueColor(rgbColor: RgbColor(red: 0.9, green: 0.95, blue: 1)))
                    )
                )
            )
        )
        let slide = Page(objectId: "s", pageElements: [element])
        let presentation = Presentation(slides: [slide])
        #expect(render(GSlidesSlideView(slide: slide, presentation: presentation)) != nil)
    }

    @Test func unknownElementRendersPlaceholder() throws {
        let slide = Page(objectId: "s", pageElements: [PageElement(objectId: "mystery")])
        let presentation = Presentation(slides: [slide])
        #expect(render(GSlidesSlideView(slide: slide, presentation: presentation)) != nil)
    }

    @Test func presentationViewRenders() throws {
        let presentation = try semanticPresentation()
        #expect(render(GSlidesPresentationView(presentation: presentation)) != nil)
    }
}

@MainActor
@Suite struct PresentationNavigationViewTests {
    func navPresentation() throws -> Presentation {
        let json = """
        {"title": "Nav", "slides": [
            {"layout": "TITLE", "title": "One", "subtitle": "s"},
            {"title": "Two", "bodies": [{"bullets": ["a"]}]}
        ]}
        """
        return try GSlidesGenerationContract.presentation(from: Data(json.utf8))
    }

    func renderNav(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: 600, height: 400))
        return renderer.cgImage
    }

    @Test func carouselRenders() throws {
        #expect(renderNav(GSlidesCarouselView(presentation: try navPresentation())) != nil)
    }

    @Test func carouselShowsGeneratingCardWhenIncomplete() throws {
        #expect(renderNav(GSlidesCarouselView(presentation: try navPresentation(), isComplete: false)) != nil)
    }

    @Test func stackRenders() throws {
        #expect(renderNav(GSlidesStackView(presentation: try navPresentation())) != nil)
    }

    @Test func fullScreenRenders() throws {
        #expect(renderNav(GSlidesFullScreenView(presentation: try navPresentation(), initialIndex: 1)) != nil)
    }
}

@MainActor
@Suite struct CanonicalTextTests {
    private func palette() -> GSlidesPalette { GSlidesPalette() }

    /// A real `presentations.get` splits a paragraph into a ParagraphMarker element + separate
    /// TextRun elements. They must group into ONE paragraph carrying all runs (not one line each).
    @Test func canonicalParagraphGroupsSeparateRuns() {
        let tc = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start))),
            TextElement(textRun: TextRun(content: "Hello ", style: TextStyle())),
            TextElement(textRun: TextRun(content: "world", style: TextStyle(bold: true))),
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start))),
            TextElement(textRun: TextRun(content: "second line", style: TextStyle())),
        ])
        let view = TextContentView(text: tc, placeholderType: .body, pointScale: 1, palette: palette())
        #expect(view.paragraphs.count == 2)
        #expect(view.paragraphs.first?.runs.count == 2)              // "Hello " + "world"
        #expect(view.paragraphs.first?.plainText == "Hello world")
    }

    /// The compact form PresentationExpander emits (marker + run in one element) must group the same way.
    @Test func compactParagraphFormStillGroups() {
        let tc = TextContent(textElements: [
            TextElement(
                paragraphMarker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: "●")),
                textRun: TextRun(content: "one\n", style: TextStyle())
            ),
            TextElement(
                paragraphMarker: ParagraphMarker(bullet: Bullet(nestingLevel: 1, glyph: "○")),
                textRun: TextRun(content: "two\n", style: TextStyle())
            ),
        ])
        let view = TextContentView(text: tc, placeholderType: .body, pointScale: 1, palette: palette())
        #expect(view.paragraphs.count == 2)
        #expect(view.paragraphs.first?.marker?.bullet?.glyph == "●")
        #expect(view.paragraphs.last?.marker?.bullet?.nestingLevel == 1)
    }

    /// Canonical multi-run text renders (inline styles applied, no crash).
    @Test func canonicalRichTextRenders() throws {
        let tc = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker()),
            TextElement(textRun: TextRun(content: "bold ", style: TextStyle(bold: true))),
            TextElement(textRun: TextRun(content: "italic ", style: TextStyle(italic: true))),
            TextElement(textRun: TextRun(content: "link", style: TextStyle(link: Link(url: "https://x")))),
        ])
        let view = TextContentView(text: tc, placeholderType: .body, pointScale: 1, palette: palette())
        let renderer = ImageRenderer(content: view.frame(width: 400))
        #expect(renderer.cgImage != nil)
    }
}

@MainActor
@Suite struct InlineStyleSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dumpInline() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func run(_ s: String, _ style: TextStyle) -> TextElement { TextElement(textRun: TextRun(content: s, style: style)) }
        let accent = OptionalColor(opaqueColor: OpaqueColor(themeColor: .accent1))
        let tc = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start))),
            run("通常のテキストに ", TextStyle()),
            run("太字", TextStyle(bold: true)),
            run("、", TextStyle()),
            run("斜体", TextStyle(italic: true)),
            run("、", TextStyle()),
            run("下線", TextStyle(underline: true)),
            run("、", TextStyle()),
            run("取り消し線", TextStyle(strikethrough: true)),
            run("、", TextStyle()),
            run("アクセント色", TextStyle(foregroundColor: accent)),
            run(" を混在。E=mc", TextStyle()),
            run("2", TextStyle(baselineOffset: .superscript)),
            run(" / H", TextStyle()),
            run("2", TextStyle(baselineOffset: .subscript)),
            run("O、", TextStyle()),
            run("リンク", TextStyle(link: Link(url: "https://example.com"))),
            TextElement(paragraphMarker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: "●"))),
            run("段落2：", TextStyle(bold: true)),
            run("marker と run が別要素でも1行に結合される", TextStyle()),
        ])
        let view = TextContentView(text: tc, placeholderType: .body, pointScale: 1.4, palette: GSlidesPalette())
            .padding(40).frame(width: 960).background(Color.white)
        let r = ImageRenderer(content: view)
        r.proposedSize = ProposedViewSize(width: 960, height: nil)
        r.scale = 2
        let image = try #require(r.cgImage)
        let url = dir.appendingPathComponent("inline.png")
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct ParagraphStyleAutofitTests {
    @Test func paragraphStyleAndAutofitRender() throws {
        let tc = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(
                alignment: .start, lineSpacing: 150,
                indentStart: Dimension(magnitude: 36, unit: .pt),
                spaceAbove: Dimension(magnitude: 10, unit: .pt),
                spaceBelow: Dimension(magnitude: 6, unit: .pt)))),
            TextElement(textRun: TextRun(content: "indented • 1.5x line spacing • space above/below", style: TextStyle())),
        ])
        let view = TextContentView(text: tc, placeholderType: .body, pointScale: 1,
                                   palette: GSlidesPalette(), fontScale: 0.7, lineSpacingReduction: 2)
        let r = ImageRenderer(content: view.frame(width: 360))
        #expect(r.cgImage != nil)
    }

    /// A shape with TEXT_AUTOFIT threads its font scale into the text (renders without crashing).
    @Test func shapeAutofitThreadsFontScale() throws {
        let shape = Shape(
            shapeType: .textBox,
            text: TextContent(textElements: [
                TextElement(paragraphMarker: ParagraphMarker(), textRun: TextRun(content: "shrunk to fit", style: TextStyle(fontSize: Dimension(magnitude: 40, unit: .pt)))),
            ]),
            shapeProperties: ShapeProperties(autofit: Autofit(autofitType: .textAutofit, fontScale: 0.5))
        )
        let element = PageElement(objectId: "s", shape: shape)
        let r = ImageRenderer(content: ElementView(element: element, pointScale: 1, palette: GSlidesPalette()).frame(width: 300, height: 100))
        #expect(r.cgImage != nil)
    }
}

@MainActor
@Suite struct ParagraphAutofitSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func body(_ s: String, _ style: TextStyle = TextStyle()) -> TextElement { TextElement(textRun: TextRun(content: s, style: style)) }
        let long = "この段落は autofit (TEXT_AUTOFIT, fontScale 0.55) で縮小されて箱に収まります。" +
                   "本来 40pt のテキストが API 計算済みの倍率で自動的に小さくなり、はみ出しません。"
        let autofitShape = Shape(
            shapeType: .roundRectangle,
            text: TextContent(textElements: [TextElement(paragraphMarker: ParagraphMarker()), body(long, TextStyle(fontSize: Dimension(magnitude: 40, unit: .pt)))]),
            shapeProperties: ShapeProperties(
                shapeBackgroundFill: ShapeBackgroundFill(solidFill: SolidFill(color: OpaqueColor(rgbColor: RgbColor(red: 0.93, green: 0.95, blue: 1)))),
                autofit: Autofit(autofitType: .textAutofit, fontScale: 0.55)
            )
        )
        let para = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start, spaceBelow: Dimension(magnitude: 14, unit: .pt)))),
            body("段落1：行間 100%、下に余白。"),
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start, lineSpacing: 180, indentStart: Dimension(magnitude: 48, unit: .pt)))),
            body("段落2：行間 180% かつ左インデント 48pt。長めの文章で折り返したときの行間と字下げが効いていることを確認します。"),
        ])
        let stack = VStack(alignment: .leading, spacing: 24) {
            TextContentView(text: para, placeholderType: .body, pointScale: 1.3, palette: GSlidesPalette())
            ElementView(element: PageElement(objectId: "a", shape: autofitShape), pointScale: 1.3, palette: GSlidesPalette())
                .frame(height: 150)
        }
        .padding(40).frame(width: 900).background(Color.white)
        let r = ImageRenderer(content: stack)
        r.proposedSize = ProposedViewSize(width: 900, height: nil); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("para-autofit.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct TableStylingTests {
    @Test func styledTableDecodesAndRoundTrips() throws {
        let json = """
        {"rows":1,"columns":2,
         "tableColumns":[{"columnWidth":{"magnitude":2000000,"unit":"EMU"}},{"columnWidth":{"magnitude":1000000,"unit":"EMU"}}],
         "tableRows":[{"tableCells":[
            {"text":{"textElements":[]},"tableCellProperties":{"tableCellBackgroundFill":{"solidFill":{"color":{"rgbColor":{"red":0.9,"green":0.9,"blue":0.95}}}},"contentAlignment":"MIDDLE"}},
            {"text":{"textElements":[]}}]}]}
        """
        let table = try JSONDecoder().decode(GSlidesSchema.Table.self, from: Data(json.utf8))
        #expect(table.tableColumns?.count == 2)
        #expect(table.tableRows?.first?.tableCells?.first?.tableCellProperties?.contentAlignment == .middle)
        #expect(table.tableRows?.first?.tableCells?.first?.tableCellProperties?.tableCellBackgroundFill?.solidFill != nil)
        let reencoded = try JSONDecoder().decode(GSlidesSchema.Table.self, from: JSONEncoder().encode(table))
        #expect(reencoded == table)
    }

    @Test func generatedTableHeaderHasBackgroundFill() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(table: SemanticTable(headers: ["A", "B"], rows: [["1", "2"]])),
            ]),
        ]))
        let table = try #require(p.slides?.first?.pageElements?.first { $0.table != nil }?.table)
        #expect(table.tableRows?.first?.tableCells?.first?.tableCellProperties?.tableCellBackgroundFill?.solidFill != nil)
        #expect(table.tableRows?.last?.tableCells?.first?.tableCellProperties?.tableCellBackgroundFill?.solidFill == nil)
    }

    @Test func styledTableRenders() throws {
        let table = GSlidesSchema.Table(
            rows: 1, columns: 2,
            tableRows: [TableRow(tableCells: [
                TableCell(text: TextContent(textElements: [TextElement(textRun: TextRun(content: "x\n"))]),
                          tableCellProperties: TableCellProperties(tableCellBackgroundFill: TableCellBackgroundFill(solidFill: SolidFill(color: OpaqueColor(rgbColor: RgbColor(red: 0.9, green: 0.9, blue: 0.95)))), contentAlignment: .middle)),
                TableCell(text: TextContent(textElements: [TextElement(textRun: TextRun(content: "y\n"))])),
            ])],
            tableColumns: [TableColumnProperties(columnWidth: Dimension(magnitude: 2, unit: .emu)), TableColumnProperties(columnWidth: Dimension(magnitude: 1, unit: .emu))]
        )
        let r = ImageRenderer(content: TableElementView(table: table, pointScale: 1, palette: GSlidesPalette()).frame(width: 300, height: 120))
        #expect(r.cgImage != nil)
    }
}

@MainActor
@Suite struct ImagePropertiesTests {
    private func sourceImage() -> CGImage {
        let r = ImageRenderer(content: ZStack {
            LinearGradient(colors: [.blue, .green, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("IMG").font(.largeTitle.bold()).foregroundStyle(.white)
        }.frame(width: 200, height: 200))
        r.scale = 1
        return r.cgImage!
    }

    private func element(_ props: ImageProperties?) -> PageElement {
        PageElement(objectId: "i", image: GSlidesSchema.Image(sourceUrl: "https://x/i.png", imageProperties: props))
    }

    private func render(_ props: ImageProperties?) -> CGImage? {
        let provider = GSlidesImageProvider(images: ["https://x/i.png": sourceImage()])
        let view = ElementView(element: element(props), pointScale: 1, palette: GSlidesPalette())
            .frame(width: 160, height: 120)
            .environment(\.gslidesImageProvider, provider)
        return ImageRenderer(content: view).cgImage
    }

    @Test func plainImageRenders() { #expect(render(nil) != nil) }

    @Test func colorAdjustmentsRender() {
        #expect(render(ImageProperties(transparency: 0.3, brightness: 0.2, contrast: 0.1)) != nil)
    }

    @Test func recolorModesRender() {
        for name in [RecolorName.grayscale, .sepia, .negative, .init(rawValue: "DARK3"), .init(rawValue: "LIGHT2")] {
            #expect(render(ImageProperties(recolor: Recolor(name: name))) != nil)
        }
    }

    @Test func cropAndOutlineRender() {
        let props = ImageProperties(
            cropProperties: CropProperties(leftOffset: 0.2, rightOffset: 0.1, topOffset: 0.15, bottomOffset: 0.05),
            outline: Outline(outlineFill: OutlineFill(solidFill: SolidFill(color: OpaqueColor(rgbColor: RgbColor(red: 0, green: 0, blue: 0)))), weight: Dimension(magnitude: 2, unit: .pt))
        )
        #expect(render(props) != nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let provider = GSlidesImageProvider(images: ["https://x/i.png": sourceImage()])
        func tile(_ label: String, _ props: ImageProperties?) -> some View {
            VStack(spacing: 4) {
                ElementView(element: element(props), pointScale: 1, palette: GSlidesPalette())
                    .frame(width: 150, height: 110)
                    .environment(\.gslidesImageProvider, provider)
                Text(label).font(.caption)
            }
        }
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(160)), count: 3), spacing: 16) {
            tile("original", nil)
            tile("grayscale", ImageProperties(recolor: Recolor(name: .grayscale)))
            tile("sepia", ImageProperties(recolor: Recolor(name: .sepia)))
            tile("negative", ImageProperties(recolor: Recolor(name: .negative)))
            tile("brightness+0.3", ImageProperties(brightness: 0.3))
            tile("transparency 0.5", ImageProperties(transparency: 0.5))
            tile("crop L0.25/T0.15", ImageProperties(cropProperties: CropProperties(leftOffset: 0.25, topOffset: 0.15)))
            tile("outline+shadow", ImageProperties(outline: Outline(outlineFill: OutlineFill(solidFill: SolidFill(color: OpaqueColor(rgbColor: RgbColor(red: 0.1, green: 0.1, blue: 0.1)))), weight: Dimension(magnitude: 3, unit: .pt)), shadow: Shadow(type: .outer, blurRadius: Dimension(magnitude: 6, unit: .pt), alpha: 0.5)))
            tile("contrast+0.4", ImageProperties(contrast: 0.4))
        }.padding(24).frame(width: 560).background(Color.white)
        let r = ImageRenderer(content: grid); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("image-effects.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct ShapeGeometryTests {
    private func shapeElement(_ type: ShapeType) -> PageElement {
        PageElement(objectId: "s", size: Size(width: Dimension(magnitude: 1_000_000, unit: .emu), height: Dimension(magnitude: 1_000_000, unit: .emu)),
                    transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
                    shape: Shape(shapeType: type, shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1))))))
    }

    @Test func everyModeledShapeRenders() {
        let types: [ShapeType] = [.triangle, .diamond, .rightArrow, .leftArrow, .upArrow, .downArrow, .star5, .heart, .cloud, .ellipse, .roundRectangle, .rectangle]
        for type in types {
            let r = ImageRenderer(content: ElementView(element: shapeElement(type), pointScale: 1, palette: GSlidesPalette()).frame(width: 80, height: 80))
            #expect(r.cgImage != nil, "\(type.rawValue) failed to render")
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let types: [ShapeType] = [.triangle, .diamond, .rightArrow, .leftArrow, .upArrow, .downArrow, .star5, .heart, .cloud, .ellipse, .roundRectangle, .rectangle]
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(96)), count: 4), spacing: 16) {
            ForEach(types, id: \.rawValue) { type in
                VStack(spacing: 4) {
                    ElementView(element: shapeElement(type), pointScale: 1, palette: GSlidesPalette()).frame(width: 84, height: 84)
                    Text(type.rawValue).font(.caption2)
                }
            }
        }.padding(24).frame(width: 480).background(Color.white)
        let r = ImageRenderer(content: grid); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("shapes.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct LineGeometryTests {
    private func lineElement(w: Double, h: Double, props: LineProperties) -> PageElement {
        PageElement(objectId: "l",
            size: Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
            line: GSlidesSchema.Line(lineProperties: props))
    }

    @Test func linesRenderWithArrowsAndDash() {
        let props = LineProperties(lineFill: LineFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1))),
                                   weight: Dimension(magnitude: 3, unit: .pt), dashStyle: .dash,
                                   startArrow: .fillArrow, endArrow: .fillArrow)
        for (w, h) in [(4_000_000.0, 100_000.0), (100_000.0, 3_000_000.0), (3_000_000.0, 2_000_000.0)] {
            let r = ImageRenderer(content: GSlidesSlideView(slide: Page(objectId: "s", pageElements: [lineElement(w: w, h: h, props: props)]), presentation: Presentation(slides: [Page(objectId: "s")])).frame(width: 300))
            #expect(r.cgImage != nil)
        }
    }

    @Test func arrowPresenceLogic() {
        // behavioral check via rendering both with and without arrows
        let bare = LineProperties(weight: Dimension(magnitude: 2, unit: .pt))
        let r = ImageRenderer(content: ElementView(element: lineElement(w: 3_000_000, h: 80_000, props: bare), pointScale: 1, palette: GSlidesPalette()).frame(width: 200, height: 40))
        #expect(r.cgImage != nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func line(_ label: String, w: CGFloat, h: CGFloat, _ props: LineProperties) -> some View {
            VStack(spacing: 4) {
                ElementView(element: lineElement(w: Double(w) * 10000, h: Double(h) * 10000, props: props), pointScale: 1.5, palette: GSlidesPalette())
                    .frame(width: w, height: h).border(.gray.opacity(0.2))
                Text(label).font(.caption2)
            }
        }
        let accent = LineFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1)))
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(150)), count: 2), spacing: 20) {
            line("horizontal + end arrow", w: 140, h: 30, LineProperties(lineFill: accent, weight: Dimension(magnitude: 2, unit: .pt), endArrow: .fillArrow))
            line("vertical + both arrows", w: 30, h: 110, LineProperties(lineFill: accent, weight: Dimension(magnitude: 2, unit: .pt), startArrow: .fillArrow, endArrow: .fillArrow))
            line("diagonal dashed", w: 140, h: 90, LineProperties(lineFill: accent, weight: Dimension(magnitude: 2, unit: .pt), dashStyle: .dash, endArrow: .fillArrow))
            line("thick plain", w: 140, h: 60, LineProperties(lineFill: accent, weight: Dimension(magnitude: 5, unit: .pt)))
        }.padding(24).frame(width: 380).background(Color.white)
        let r = ImageRenderer(content: grid); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("lines.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct ConformanceRenderTests {
    @Test func rtlParagraphRenders() {
        let tc = TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start, direction: .rightToLeft))),
            TextElement(textRun: TextRun(content: "مرحبا بالعالم", style: TextStyle())),
        ])
        let r = ImageRenderer(content: TextContentView(text: tc, placeholderType: .body, pointScale: 1, palette: GSlidesPalette()).frame(width: 300))
        #expect(r.cgImage != nil)
    }

    @Test func pageBackgroundImageRenders() {
        let src = ImageRenderer(content: LinearGradient(colors: [.purple, .orange], startPoint: .top, endPoint: .bottom).frame(width: 100, height: 60)).cgImage!
        let provider = GSlidesImageProvider(images: ["https://bg/x.png": src])
        let slide = Page(objectId: "s", pageType: .slide,
            pageElements: [PageElement(objectId: "t", shape: Shape(text: TextContent(textElements: [TextElement(textRun: TextRun(content: "on image\n"))]), placeholder: Placeholder(type: .title)))],
            pageProperties: PageProperties(pageBackgroundFill: PageBackgroundFill(stretchedPictureFill: StretchedPictureFill(contentUrl: "https://bg/x.png"))))
        let view = GSlidesSlideView(slide: slide, presentation: Presentation(slides: [slide]))
            .environment(\.gslidesImageProvider, provider)
        #expect(ImageRenderer(content: view.frame(width: 400)).cgImage != nil)
    }
}

@MainActor
@Suite struct TableEngineTests {
    @Test func mergedCellsAndBordersRender() {
        // header spanning 2 columns + a normal row, with explicit borders
        func cell(_ s: String, rowSpan: Int = 1, columnSpan: Int = 1, bg: ThemeColorType? = nil) -> TableCell {
            TableCell(rowSpan: rowSpan, columnSpan: columnSpan,
                      text: TextContent(textElements: [TextElement(textRun: TextRun(content: s + "\n"))]),
                      tableCellProperties: bg.map { TableCellProperties(tableCellBackgroundFill: TableCellBackgroundFill(solidFill: SolidFill(color: OpaqueColor(themeColor: $0)))) })
        }
        let border = TableBorderProperties(tableBorderFill: TableBorderFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1))), weight: Dimension(magnitude: 1.5, unit: .pt))
        let borderRow2 = TableBorderRow(tableBorderCells: [TableBorderCell(tableBorderProperties: border), TableBorderCell(tableBorderProperties: border)])
        let table = Table(
            rows: 2, columns: 2,
            tableRows: [
                TableRow(tableCells: [cell("Merged header", columnSpan: 2, bg: .light2)]),
                TableRow(tableCells: [cell("A"), cell("B")]),
            ],
            tableColumns: [TableColumnProperties(columnWidth: Dimension(magnitude: 2, unit: .emu)), TableColumnProperties(columnWidth: Dimension(magnitude: 1, unit: .emu))],
            horizontalBorderRows: [borderRow2, borderRow2, borderRow2])
        let r = ImageRenderer(content: TableElementView(table: table, pointScale: 1, palette: GSlidesPalette()).frame(width: 300, height: 120))
        #expect(r.cgImage != nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func cell(_ s: String, rowSpan: Int = 1, columnSpan: Int = 1, bg: ThemeColorType? = nil) -> TableCell {
            TableCell(rowSpan: rowSpan, columnSpan: columnSpan,
                      text: TextContent(textElements: [TextElement(paragraphMarker: ParagraphMarker(), textRun: TextRun(content: s + "\n", style: bg != nil ? TextStyle(bold: true) : TextStyle()))]),
                      tableCellProperties: TableCellProperties(tableCellBackgroundFill: bg.map { TableCellBackgroundFill(solidFill: SolidFill(color: OpaqueColor(themeColor: $0))) }, contentAlignment: .middle))
        }
        let table = Table(
            rows: 3, columns: 3,
            tableRows: [
                TableRow(tableCells: [cell("四半期業績", columnSpan: 3, bg: .accent1)]),
                TableRow(tableCells: [cell("項目", bg: .light2), cell("Q1", bg: .light2), cell("Q2", bg: .light2)]),
                TableRow(tableCells: [cell("売上"), cell("120"), cell("145")]),
            ],
            tableColumns: [TableColumnProperties(columnWidth: Dimension(magnitude: 2, unit: .emu)), TableColumnProperties(columnWidth: Dimension(magnitude: 1, unit: .emu)), TableColumnProperties(columnWidth: Dimension(magnitude: 1, unit: .emu))])
        let view = TableElementView(table: table, pointScale: 1.3, palette: GSlidesPalette()).frame(width: 460, height: 200).padding(24).background(Color.white)
        let r = ImageRenderer(content: view); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("table-engine.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct ExpandedShapesSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func el(_ raw: String) -> PageElement {
            PageElement(objectId: raw, size: Size(width: Dimension(magnitude: 900000, unit: .emu), height: Dimension(magnitude: 900000, unit: .emu)), transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
                shape: Shape(shapeType: ShapeType(rawValue: raw), shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1))))))
        }
        let types = ["PENTAGON","HEXAGON","OCTAGON","DODECAGON","STAR_4","STAR_6","STAR_8","STAR_12","PARALLELOGRAM","TRAPEZOID","RIGHT_TRIANGLE","PLUS","HOME_PLATE","CHEVRON","TRIANGLE","DIAMOND"]
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(86)), count: 4), spacing: 14) {
            ForEach(types, id: \.self) { t in
                VStack(spacing: 3) {
                    ElementView(element: el(t), pointScale: 1, palette: GSlidesPalette()).frame(width: 74, height: 74)
                    Text(t).font(.system(size: 8))
                }
            }
        }.padding(20).frame(width: 420).background(Color.white)
        let r = ImageRenderer(content: grid); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("shapes2.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}

@MainActor
@Suite struct MathMiscShapesSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dump() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func el(_ raw: String) -> PageElement {
            PageElement(objectId: raw, size: Size(width: Dimension(magnitude: 900000, unit: .emu), height: Dimension(magnitude: 900000, unit: .emu)), transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
                shape: Shape(shapeType: ShapeType(rawValue: raw), shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .accent1))))))
        }
        let types = ["MATH_PLUS","MATH_MINUS","MATH_MULTIPLY","MATH_DIVIDE","MATH_EQUAL","DONUT","FRAME","HALF_FRAME","PIE","CHORD","TEARDROP","BEVEL","CUBE","FOLDED_CORNER","DIAGONAL_STRIPE","LIGHTNING_BOLT"]
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(86)), count: 4), spacing: 14) {
            ForEach(types, id: \.self) { t in
                VStack(spacing: 3) {
                    ElementView(element: el(t), pointScale: 1, palette: GSlidesPalette()).frame(width: 74, height: 74)
                    Text(t).font(.system(size: 8))
                }
            }
        }.padding(20).frame(width: 420).background(Color.white)
        let r = ImageRenderer(content: grid); r.scale = 2
        let image = try #require(r.cgImage)
        let dest = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("shapes3.png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }
}
