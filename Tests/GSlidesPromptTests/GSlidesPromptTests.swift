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

@Suite struct ImageLayoutTests {
    @Test func bodyWithTextAndImageSplitsLeftRight() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(bullets: ["a", "b"], imageUrl: "https://x/i.png"),
            ]),
        ]))
        let els = p.slides!.first!.pageElements!
        let body = try #require(els.first { $0.shape?.placeholder?.type == .body })
        let image = try #require(els.first { $0.image != nil })
        // image starts to the right of where the text box ends (no overlap)
        let textRight = (body.transform!.translateX!) + (body.size!.width!.magnitude!)
        #expect(image.transform!.translateX! >= textRight)
    }

    @Test func titleSlideDropsStrayImages() {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE", title: "T", subtitle: "s", bodies: [SemanticBody(imageUrl: "https://x/i.png")]),
        ]))
        #expect(!(p.slides!.first!.pageElements!).contains { $0.image != nil })
    }

    @Test func imageOnlyBodyFillsBodyArea() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [SemanticBody(imageUrl: "https://x/i.png")]),
        ]))
        let image = try #require(p.slides!.first!.pageElements!.first { $0.image != nil })
        #expect(image.size?.width?.magnitude != nil)
    }

    /// Regression: a model that splits bullets and image into SEPARATE bodies on a single-column
    /// layout must still get side-by-side columns, not two elements stacked in the same rect.
    @Test func separateTextAndImageBodiesDoNotOverlap() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(bullets: ["a", "b", "c"]),
                SemanticBody(imageUrl: "https://x/i.png"),
            ]),
        ]))
        let els = try #require(p.slides?.first?.pageElements)
        let textBody = try #require(els.first { $0.shape?.placeholder?.type == .body && $0.shape?.text != nil })
        let image = try #require(els.first { $0.image != nil })
        let textRight = textBody.transform!.translateX! + textBody.size!.width!.magnitude!
        #expect(image.transform!.translateX! >= textRight) // image column is to the right of text
    }
}

@Suite struct DeckThemeTests {
    /// The master `ColorScheme` must mirror a real `presentations.get` master: all 16
    /// `ThemeColorType`s present, every type ⊆ the discovery enum (knownValues).
    @Test func masterEnumeratesAll16ThemeColorTypesForBothThemes() throws {
        for theme in DeckColorTheme.allCases {
            let colors = try #require(DeckTemplate.master(theme: theme).pageProperties?.colorScheme?.colors)
            let types = colors.compactMap(\.type)
            #expect(types.count == 16)
            // every emitted type is a known protocol value (no invented vocabulary)
            for type in types { #expect(ThemeColorType.knownValues.contains(type)) }
            // the four alias slots are present and carry the conventional mapping
            func rgb(_ t: ThemeColorType) -> RgbColor? { colors.first { $0.type == t }?.color }
            #expect(rgb(.text1) == rgb(.dark1))
            #expect(rgb(.background1) == rgb(.light1))
            #expect(rgb(.text2) == rgb(.dark2))
            #expect(rgb(.background2) == rgb(.light2))
        }
    }

    /// Light vs dark differ only in RGB: dark has a dark canvas (light1) and light text (dark1).
    @Test func darkThemeInvertsCanvasAndText() throws {
        func light1(_ theme: DeckColorTheme) throws -> RgbColor {
            let colors = try #require(DeckTemplate.master(theme: theme).pageProperties?.colorScheme?.colors)
            return try #require(colors.first { $0.type == .light1 }?.color)
        }
        // light theme canvas (light1) is near-white; dark theme canvas is near-black
        #expect(try light1(.light).red! > 0.9)
        #expect(try light1(.dark).red! < 0.2)
    }

    @Test func deckThemeHintOverridesCallerDefault() throws {
        let dark = DeckExpander.expand(SemanticDeck(title: "x", theme: "dark", slides: [SemanticSlide(title: "A")]), theme: .light)
        let canvas = try #require(dark.masters?.first?.pageProperties?.colorScheme?.colors?.first { $0.type == .light1 }?.color)
        #expect(canvas.red! < 0.2) // hint "dark" wins over the .light seed
    }

    @Test func callerThemeUsedWhenNoHint() throws {
        let dark = DeckExpander.expand(SemanticDeck(title: "x", slides: [SemanticSlide(title: "A")]), theme: .dark)
        let canvas = try #require(dark.masters?.first?.pageProperties?.colorScheme?.colors?.first { $0.type == .light1 }?.color)
        #expect(canvas.red! < 0.2)
    }

    @Test func schemaExposesThemeEnum() throws {
        let text = String(decoding: try GSlidesGenerationContract.jsonSchemaData(), as: UTF8.self)
        #expect(text.contains("\"theme\""))
        #expect(text.contains("light"))
        #expect(text.contains("dark"))
    }
}

@Suite struct VocabularyTests {
    @Test func bulletDecodesFromStringOrObject() throws {
        let json = #"[{"text":"a"},"b",{"text":"c","level":2}]"#
        let bullets = try JSONDecoder().decode([SemanticBullet].self, from: Data(json.utf8))
        #expect(bullets.map(\.text) == ["a", "b", "c"])
        #expect(bullets.map(\.level) == [0, 0, 2])
    }

    @Test func bulletEncodesLevelZeroAsBareString() throws {
        let data = try JSONEncoder().encode([SemanticBullet("a"), SemanticBullet("b", level: 1)])
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"a\""))        // level 0 → bare string
        #expect(text.contains("\"level\":1"))  // nested → object
    }

    @Test func multiLevelBulletsCarryNestingLevelAndGlyph() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(bullets: ["top", SemanticBullet("sub", level: 1)]),
            ]),
        ]))
        let body = try #require(p.slides?.first?.pageElements?.first { $0.shape?.placeholder?.type == .body })
        let markers = try #require(body.shape?.text?.textElements).compactMap { $0.paragraphMarker?.bullet }
        #expect(markers.map(\.nestingLevel) == [0, 1])
        #expect(markers[0].glyph != markers[1].glyph) // distinct glyph per level
    }

    @Test func backwardCompatFlatStringBullets() {
        // existing [String]-literal call sites keep working via ExpressibleByStringLiteral
        let body = SemanticBody(bullets: ["a", "b"])
        #expect(body.bullets?.map(\.level) == [0, 0])
    }

    @Test func tableBodyExpandsToTableElement() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(table: SemanticTable(headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]])),
            ]),
        ]))
        let element = try #require(p.slides?.first?.pageElements?.first { $0.table != nil })
        let table = try #require(element.table)
        #expect(table.rows == 3)      // 1 header + 2 data rows
        #expect(table.columns == 2)
        // header cells are emphasized (bold)
        let headerCell = try #require(table.tableRows?.first?.tableCells?.first)
        #expect(headerCell.text?.textElements?.first?.textRun?.style?.bold == true)
        // table carries baked geometry (fills the body box)
        #expect(element.size?.width?.magnitude != nil)
    }

    @Test func raggedTableRowsArePaddedToWidest() throws {
        let p = DeckExpander.expand(SemanticDeck(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [
                SemanticBody(table: SemanticTable(rows: [["a", "b", "c"], ["x"]])),
            ]),
        ]))
        let table = try #require(p.slides?.first?.pageElements?.first { $0.table != nil }?.table)
        #expect(table.columns == 3)
        #expect(table.tableRows?.allSatisfy { ($0.tableCells?.count ?? 0) == 3 } == true)
    }

    @Test func schemaExposesTableAndNestedBullets() throws {
        let text = String(decoding: try GSlidesGenerationContract.jsonSchemaData(), as: UTF8.self)
        #expect(text.contains("\"table\""))
        #expect(text.contains("\"level\""))
        #expect(text.contains("oneOf"))
    }

    @Test func exampleDeckWithTableAndNestingStillValidates() throws {
        // the worked example must round-trip through the validation sandwich
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.exampleDeckJSON().utf8))
        #expect((presentation.slides?.count ?? 0) > 0)
        #expect(presentation.slides?.contains { ($0.pageElements ?? []).contains { $0.table != nil } } == true)
    }
}
