import Foundation
import Testing
import GSlidesSchema
import GSlidesLayout
@testable import GSlidesPrompt

@Suite struct GenerationContractTests {
    @Test func schemaIsValidJSONAndListsAllLayouts() throws {
        let data = try GSlidesGenerationContract.jsonSchemaData()
        let text = String(decoding: data, as: UTF8.self)
        for layout in GSlidesGenerationContract.allowedLayouts {
            #expect(text.contains(layout))
        }
        #expect(!text.contains("PREDEFINED_LAYOUT_UNSPECIFIED"))
    }

    @Test func validDeckPassesValidation() throws {
        let json = """
        {"title": "Demo", "slides": [
            {"layout": "TITLE", "title": "Hello", "subtitle": "World"},
            {"title": "Points", "bodies": [{"bullets": ["a", "b"]}]}
        ]}
        """
        let deck = try GSlidesGenerationContract.validate(Data(json.utf8))
        #expect(deck.slides.count == 2)
    }

    @Test func unknownLayoutIsRejected() {
        let json = """
        {"title": "Demo", "slides": [{"layout": "HERO_SPLASH", "title": "x"}]}
        """
        #expect(throws: GenerationContractError.self) {
            _ = try GSlidesGenerationContract.validate(Data(json.utf8))
        }
    }

    @Test func emptyDeckIsRejected() {
        let json = #"{"title": "Demo", "slides": []}"#
        #expect(throws: GenerationContractError.emptyDeck) {
            _ = try GSlidesGenerationContract.validate(Data(json.utf8))
        }
    }

    @Test func malformedJSONIsRejected() {
        #expect(throws: GenerationContractError.self) {
            _ = try GSlidesGenerationContract.validate(Data("not json".utf8))
        }
    }
}

@Suite struct DeckExpanderTests {
    @Test func titleSlideExpandsToCenteredTitlePlaceholders() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(layout: "TITLE", title: "Hello", subtitle: "World")
        ])
        let presentation = DeckExpander.expand(deck)
        let slide = try #require(presentation.slides?.first)
        let types = (slide.pageElements ?? []).compactMap { $0.shape?.placeholder?.type }
        #expect(types == [.centeredTitle, .subtitle])
        #expect(slide.slideProperties?.layoutObjectId == "layout-TITLE")
    }

    @Test func layoutIsInferredWhenOmitted() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(title: "Section")
        ])
        let presentation = DeckExpander.expand(deck)
        #expect(presentation.slides?.first?.slideProperties?.layoutObjectId == "layout-SECTION_HEADER")
    }

    @Test func bigTitleInfersMainPoint() {
        let slide = SemanticSlide(title: "42%", big: true)
        #expect(DeckExpander.resolvedLayout(of: slide) == .mainPoint)
    }

    @Test func usedLayoutsAreSynthesizedAsLayoutPages() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(title: "A", bodies: [SemanticBody(bullets: ["x"])]),
            SemanticSlide(title: "B", bodies: [SemanticBody(bullets: ["y"])]),
        ])
        let presentation = DeckExpander.expand(deck)
        let layouts = presentation.layouts ?? []
        #expect(layouts.count == 1)
        #expect(layouts.first?.layoutProperties?.name == "TITLE_AND_BODY")
        #expect(layouts.first?.pageType == .layout)
    }

    @Test func bulletsBecomeBulletedParagraphs() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(title: "Points", bodies: [SemanticBody(bullets: ["one", "two"])])
        ])
        let presentation = DeckExpander.expand(deck)
        let body = try #require(
            presentation.slides?.first?.pageElements?
                .first { $0.shape?.placeholder?.type == .body }
        )
        let elements = try #require(body.shape?.text?.textElements)
        #expect(elements.count == 2)
        #expect(elements.allSatisfy { $0.paragraphMarker?.bullet != nil })
        #expect(elements.first?.textRun?.content == "one\n")
    }

    @Test func twoColumnBodiesGetDistinctPlaceholderIndices() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(
                layout: "TITLE_AND_TWO_COLUMNS",
                title: "Compare",
                bodies: [SemanticBody(text: "left"), SemanticBody(text: "right")]
            )
        ])
        let presentation = DeckExpander.expand(deck)
        let bodies = (presentation.slides?.first?.pageElements ?? [])
            .filter { $0.shape?.placeholder?.type == .body }
        #expect(bodies.compactMap { $0.shape?.placeholder?.index } == [0, 1])
    }

    @Test func imageBodyBecomesImageElement() throws {
        let deck = SemanticDeck(title: "Demo", slides: [
            SemanticSlide(title: "Pic", bodies: [SemanticBody(imageUrl: "https://example.com/x.png")])
        ])
        let presentation = DeckExpander.expand(deck)
        let image = try #require(presentation.slides?.first?.pageElements?.first { $0.image != nil })
        #expect(image.image?.sourceUrl == "https://example.com/x.png")
        #expect(image.image?.placeholder?.type == .picture)
    }

    @Test func expandedPresentationRoundTripsThroughProfile() throws {
        let json = """
        {"title": "E2E", "slides": [
            {"layout": "TITLE", "title": "Hello", "subtitle": "World"},
            {"layout": "BIG_NUMBER", "title": "42%", "big": true, "bodies": [{"text": "of everything"}]},
            {"title": "List", "bodies": [{"bullets": ["a", "b", "c"]}]}
        ]}
        """
        let presentation = try GSlidesGenerationContract.presentation(from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(presentation)
        let decoded = try JSONDecoder().decode(Presentation.self, from: encoded)
        #expect(decoded == presentation)
        #expect(decoded.slides?.count == 3)
    }
}

@Suite struct PromptBlockTests {
    /// The A2UI invariant: the typed example, serialized, still validates against the schema
    /// (built from the type system → guaranteed structurally valid, and re-checked here).
    @Test func exampleValidatesAgainstSchema() throws {
        let validated = try GSlidesGenerationContract.validate(Data(GSlidesGenerationContract.exampleDeckJSON().utf8))
        #expect(validated.slides.count == GSlidesGenerationContract.exampleDeck().slides.count)
    }

    /// The example is a real quality bar: a big, varied deck exercising every core layout.
    @Test func exampleExercisesEveryLayout() {
        let deck = GSlidesGenerationContract.exampleDeck()
        #expect(deck.slides.count >= 8)
        let layouts = Set(deck.slides.map { DeckExpander.resolvedLayout(of: $0).rawValue })
        for expected in ["TITLE", "SECTION_HEADER", "TITLE_AND_BODY", "TITLE_AND_TWO_COLUMNS", "BIG_NUMBER", "MAIN_POINT"] {
            #expect(layouts.contains(expected), "example missing \(expected)")
        }
    }

    /// The example expands end-to-end into a profile presentation (no dangling references).
    @Test func examplePresentationExpands() throws {
        let deck = GSlidesGenerationContract.exampleDeck()
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.exampleDeckJSON().utf8))
        #expect(presentation.slides?.count == deck.slides.count)
        #expect(presentation.layouts?.isEmpty == false)
    }

    /// JSON is deterministic (stable prompt cache): same bytes every call.
    @Test func exampleJSONIsDeterministic() {
        #expect(GSlidesGenerationContract.exampleDeckJSON() == GSlidesGenerationContract.exampleDeckJSON())
    }

    /// The composed prompt block carries the schema (all layouts), the example, and A2UI-style markers.
    @Test func promptBlockContainsSchemaAndExample() {
        let block = GSlidesGenerationContract.promptBlock()
        #expect(block.contains("SLIDE DECK SCHEMA"))
        #expect(block.contains("### Examples:"))
        #expect(block.contains("---BEGIN"))
        #expect(block.contains("---END"))
        for layout in GSlidesGenerationContract.allowedLayouts {
            #expect(block.contains(layout))
        }
        #expect(block.contains(GSlidesGenerationContract.exampleDeck().title)) // the example title
    }
}

@Suite struct DeckTemplateTests {
    @Test func masterCarriesThemeColorScheme() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [SemanticSlide(title: "A")]))
        let scheme = try #require(p.masters?.first?.pageProperties?.colorScheme)
        #expect(scheme.rgb(for: .accent1) != nil)
        #expect(scheme.rgb(for: .text1) != nil)
        #expect(scheme.rgb(for: .background1) != nil)
    }

    @Test func slideElementsCarryBakedGeometryAndStyle() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "BIG_NUMBER", title: "42%", big: true, bodies: [SemanticBody(text: "of teams")]),
        ]))
        let title = try #require(p.slides?.first?.pageElements?.first { $0.shape?.placeholder?.type == .title })
        // geometry baked in (renderer's positioned path can place it)
        #expect(title.size?.width?.magnitude != nil)
        #expect(title.transform?.translateX != nil)
        // the big number is accent-colored and large, from the template
        let run = try #require(title.shape?.text?.textElements?.first?.textRun)
        #expect(run.style?.foregroundColor?.opaqueColor?.themeColor == .accent1)
        #expect((run.style?.fontSize?.pointMagnitude ?? 0) >= 80)
    }

    @Test func layoutPagesReferenceMasterAndHavePlaceholders() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_TWO_COLUMNS", title: "T", bodies: [SemanticBody(text: "l"), SemanticBody(text: "r")]),
        ]))
        let layout = try #require(p.layouts?.first)
        #expect(layout.layoutProperties?.masterObjectId == DeckTemplate.masterObjectId)
        let bodyIndices = (layout.pageElements ?? []).compactMap { $0.shape?.placeholder }.filter { $0.type == .body }.compactMap(\.index)
        #expect(Set(bodyIndices) == [0, 1])
    }

    @Test func slideReferencesTemplateMaster() {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [SemanticSlide(title: "A")]))
        #expect(p.slides?.first?.slideProperties?.masterObjectId == DeckTemplate.masterObjectId)
    }
}

@Suite struct DeckDecorationTests {
    func slide(_ layout: String) -> Page {
        DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: layout, title: "T", bodies: [SemanticBody(text: "b")]),
        ])).slides!.first!
    }

    @Test func contentSlidesGetAccentBarAndPageNumber() throws {
        let s = slide("TITLE_AND_BODY")
        // an accent-filled rectangle (no placeholder) provides the color/structure
        let accent = (s.pageElements ?? []).first { $0.shape?.shapeType == .rectangle && $0.shape?.placeholder == nil }
        let fill = try #require(accent?.shape?.shapeProperties?.shapeBackgroundFill?.solidFill?.color?.themeColor)
        #expect(fill == .accent1)
        // page number footer
        let pageNo = (s.pageElements ?? []).first { $0.objectId.hasSuffix("-pageno") }
        #expect(pageNo?.shape?.text?.textElements?.first?.textRun?.content == "1")
    }

    @Test func sectionAndTitleGetAccentButNoPageNumber() {
        for layout in ["SECTION_HEADER", "TITLE"] {
            let s = slide(layout)
            #expect((s.pageElements ?? []).contains { $0.objectId.hasSuffix("-accent") })
            #expect(!(s.pageElements ?? []).contains { $0.objectId.hasSuffix("-pageno") })
        }
    }
}
