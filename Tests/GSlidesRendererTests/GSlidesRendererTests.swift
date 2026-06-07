import Foundation
import SwiftUI
import Testing
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
            {"layout": "BIG_NUMBER", "title": "42%", "big": true, "bodies": [{"text": "of decks are JSON"}]},
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

    @Test func deckViewRenders() throws {
        let presentation = try semanticPresentation()
        #expect(render(GSlidesDeckView(presentation: presentation)) != nil)
    }
}
