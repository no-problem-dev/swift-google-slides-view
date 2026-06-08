import Foundation
import Testing
import GSlidesSchema
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
    /// The A2UI invariant: the bundled example never contradicts the schema.
    @Test func exampleValidatesAgainstSchema() throws {
        let deck = try GSlidesGenerationContract.exampleDeck()
        #expect(deck.slides.count >= 3)
    }

    /// The example is a real quality bar: it exercises several distinct layouts.
    @Test func exampleExercisesMultipleLayouts() throws {
        let deck = try GSlidesGenerationContract.exampleDeck()
        let layouts = Set(deck.slides.map { DeckExpander.resolvedLayout(of: $0).rawValue })
        #expect(layouts.count >= 3)
        #expect(layouts.contains("TITLE"))
        #expect(layouts.contains("BIG_NUMBER"))
        #expect(layouts.contains("TITLE_AND_TWO_COLUMNS"))
    }

    /// The example expands end-to-end into a profile presentation (no dangling references).
    @Test func examplePresentationExpands() throws {
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.exampleDeckJSON.utf8))
        #expect(presentation.slides?.count == 4)
        #expect(presentation.layouts?.isEmpty == false)
    }

    /// The composed prompt block carries both the schema (all layouts) and the example.
    @Test func promptBlockContainsSchemaAndExample() {
        let block = GSlidesGenerationContract.promptBlock()
        #expect(block.contains("SLIDE DECK SCHEMA"))
        #expect(block.contains("EXAMPLE"))
        for layout in GSlidesGenerationContract.allowedLayouts {
            #expect(block.contains(layout))
        }
        #expect(block.contains("Quarterly Product Review")) // the example title
    }
}
