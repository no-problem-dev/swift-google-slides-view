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

    @Test func validPresentationPassesValidation() throws {
        let json = """
        {"title": "Demo", "slides": [
            {"layout": "TITLE", "title": "Hello", "subtitle": "World"},
            {"title": "Points", "bodies": [{"bullets": ["a", "b"]}]}
        ]}
        """
        let presentation = try GSlidesGenerationContract.validate(Data(json.utf8))
        #expect(presentation.slides.count == 2)
    }

    @Test func unknownLayoutIsRejected() {
        let json = """
        {"title": "Demo", "slides": [{"layout": "HERO_SPLASH", "title": "x"}]}
        """
        #expect(throws: GenerationContractError.self) {
            _ = try GSlidesGenerationContract.validate(Data(json.utf8))
        }
    }

    @Test func emptyPresentationIsRejected() {
        let json = #"{"title": "Demo", "slides": []}"#
        #expect(throws: GenerationContractError.emptyPresentation) {
            _ = try GSlidesGenerationContract.validate(Data(json.utf8))
        }
    }

    @Test func malformedJSONIsRejected() {
        #expect(throws: GenerationContractError.self) {
            _ = try GSlidesGenerationContract.validate(Data("not json".utf8))
        }
    }
}

@Suite struct PresentationExpanderTests {
    @Test func titleSlideExpandsToCenteredTitlePlaceholders() throws {
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(layout: "TITLE", title: "Hello", subtitle: "World")
        ])
        let presentation = PresentationExpander.expand(semantic)
        let slide = try #require(presentation.slides?.first)
        let types = (slide.pageElements ?? []).compactMap { $0.shape?.placeholder?.type }
        #expect(types == [.centeredTitle, .subtitle])
        #expect(slide.slideProperties?.layoutObjectId == "layout-TITLE")
    }

    @Test func layoutIsInferredWhenOmitted() throws {
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(title: "Section")
        ])
        let presentation = PresentationExpander.expand(semantic)
        #expect(presentation.slides?.first?.slideProperties?.layoutObjectId == "layout-SECTION_HEADER")
    }

    @Test func bigTitleInfersMainPoint() {
        let slide = SemanticSlide(title: "42%", big: true)
        #expect(PresentationExpander.resolvedLayout(of: slide) == .mainPoint)
    }

    @Test func usedLayoutsAreSynthesizedAsLayoutPages() throws {
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(title: "A", bodies: [SemanticBody(bullets: ["x"])]),
            SemanticSlide(title: "B", bodies: [SemanticBody(bullets: ["y"])]),
        ])
        let presentation = PresentationExpander.expand(semantic)
        let layouts = presentation.layouts ?? []
        #expect(layouts.count == 1)
        #expect(layouts.first?.layoutProperties?.name == "TITLE_AND_BODY")
        #expect(layouts.first?.pageType == .layout)
    }

    @Test func bulletsBecomeBulletedParagraphs() throws {
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(title: "Points", bodies: [SemanticBody(bullets: ["one", "two"])])
        ])
        let presentation = PresentationExpander.expand(semantic)
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
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(
                layout: "TITLE_AND_TWO_COLUMNS",
                title: "Compare",
                bodies: [SemanticBody(text: "left"), SemanticBody(text: "right")]
            )
        ])
        let presentation = PresentationExpander.expand(semantic)
        let bodies = (presentation.slides?.first?.pageElements ?? [])
            .filter { $0.shape?.placeholder?.type == .body }
        #expect(bodies.compactMap { $0.shape?.placeholder?.index } == [0, 1])
    }

    @Test func imageBodyBecomesImageElement() throws {
        let semantic = SemanticPresentation(title: "Demo", slides: [
            SemanticSlide(title: "Pic", bodies: [SemanticBody(imageUrl: "https://example.com/x.png")])
        ])
        let presentation = PresentationExpander.expand(semantic)
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
        let validated = try GSlidesGenerationContract.validate(Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
        #expect(validated.slides.count == GSlidesGenerationContract.examplePresentation().slides.count)
    }

    /// The example is a real quality bar: a big, varied presentation exercising every core layout.
    @Test func exampleExercisesEveryLayout() {
        let presentation = GSlidesGenerationContract.examplePresentation()
        #expect(presentation.slides.count >= 8)
        let layouts = Set(presentation.slides.map { PresentationExpander.resolvedLayout(of: $0).rawValue })
        for expected in ["TITLE", "SECTION_HEADER", "TITLE_AND_BODY", "TITLE_AND_TWO_COLUMNS", "BIG_NUMBER", "MAIN_POINT"] {
            #expect(layouts.contains(expected), "example missing \(expected)")
        }
    }

    /// The example expands end-to-end into a profile presentation (no dangling references).
    @Test func examplePresentationExpands() throws {
        let semantic = GSlidesGenerationContract.examplePresentation()
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
        #expect(presentation.slides?.count == semantic.slides.count)
        #expect(presentation.layouts?.isEmpty == false)
    }

    /// JSON is deterministic (stable prompt cache): same bytes every call.
    @Test func exampleJSONIsDeterministic() {
        #expect(GSlidesGenerationContract.examplePresentationJSON() == GSlidesGenerationContract.examplePresentationJSON())
    }

    /// The composed prompt block carries the schema (all layouts), the example, and A2UI-style markers.
    @Test func promptBlockContainsSchemaAndExample() {
        let block = GSlidesGenerationContract.promptBlock()
        #expect(block.contains("SLIDE PRESENTATION SCHEMA"))
        #expect(block.contains("### Examples:"))
        #expect(block.contains("---BEGIN"))
        #expect(block.contains("---END"))
        for layout in GSlidesGenerationContract.allowedLayouts {
            #expect(block.contains(layout))
        }
        #expect(block.contains(GSlidesGenerationContract.examplePresentation().title)) // the example title
    }
}

@Suite struct PresentationTemplateTests {
    @Test func masterCarriesThemeColorScheme() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [SemanticSlide(title: "A")]))
        let scheme = try #require(p.masters?.first?.pageProperties?.colorScheme)
        #expect(scheme.rgb(for: .accent1) != nil)
        #expect(scheme.rgb(for: .text1) != nil)
        #expect(scheme.rgb(for: .background1) != nil)
    }

    @Test func slideElementsCarryBakedGeometryAndStyle() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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

    @Test func styledPropagatesTypographyFromSpecToRuns() throws {
        let spec = PlaceholderSpec(
            x: 0, y: 0, w: 100, h: 100, fontSizePt: 18, themeColor: .text1, bold: false,
            align: .start, vAlign: .top, fontFamily: "Hiragino Sans", weight: 600
        )
        let text = TextContent(textElements: [TextElement(textRun: TextRun(content: "本文", style: nil))])

        let styled = PresentationExpander.styled(text, with: spec)

        let run = try #require(styled.textElements?.first?.textRun)
        #expect(run.style?.fontFamily == "Hiragino Sans")
        #expect(run.style?.weightedFontFamily?.fontFamily == "Hiragino Sans")
        #expect(run.style?.weightedFontFamily?.weight == 600)
    }

    @Test func styledLeavesTypographyUnsetWhenSpecHasNone() throws {
        let spec = PlaceholderSpec(
            x: 0, y: 0, w: 100, h: 100, fontSizePt: 18, themeColor: .text1, bold: false,
            align: .start, vAlign: .top
        )
        let text = TextContent(textElements: [TextElement(textRun: TextRun(content: "本文", style: nil))])

        let styled = PresentationExpander.styled(text, with: spec)

        let run = try #require(styled.textElements?.first?.textRun)
        #expect(run.style?.fontFamily == nil)
        #expect(run.style?.weightedFontFamily == nil)
    }

    /// `expand(typography:)` overlays the scale onto each slot by its semantic role: a title run
    /// carries the title weight, a body run the body weight, and a BIG_NUMBER title the bigNumber
    /// weight — all on the supplied family.
    @Test func expandInjectsTypographyByRole() throws {
        let typography = PresentationTypography([
            .title: .init(fontFamily: "Hiragino Sans", weight: 700),
            .body: .init(fontFamily: "Hiragino Sans", weight: 400),
            .bigNumber: .init(fontFamily: "Hiragino Sans", weight: 800),
        ])
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "結論", bodies: [SemanticBody(text: "本文")]),
            SemanticSlide(layout: "BIG_NUMBER", title: "120%"),
        ]), typography: typography)

        let titleRun = try #require(p.slides?.first?.pageElements?
            .first { $0.shape?.placeholder?.type == .title }?.shape?.text?.textElements?.first?.textRun)
        #expect(titleRun.style?.fontFamily == "Hiragino Sans")
        #expect(titleRun.style?.weightedFontFamily?.weight == 700)

        let bodyRun = try #require(p.slides?.first?.pageElements?
            .first { $0.shape?.placeholder?.type == .body }?.shape?.text?.textElements?.first?.textRun)
        #expect(bodyRun.style?.weightedFontFamily?.weight == 400)

        let bigRun = try #require(p.slides?.last?.pageElements?
            .first { $0.shape?.placeholder?.type == .title }?.shape?.text?.textElements?.first?.textRun)
        #expect(bigRun.style?.weightedFontFamily?.weight == 800)
    }

    /// The default `.system` typography leaves runs without a family/weighted family — a presentation
    /// that specifies no typography renders exactly as before.
    @Test func expandWithoutTypographyLeavesRunsUnstyled() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "結論", bodies: [SemanticBody(text: "本文")]),
        ]))
        let titleRun = try #require(p.slides?.first?.pageElements?
            .first { $0.shape?.placeholder?.type == .title }?.shape?.text?.textElements?.first?.textRun)
        #expect(titleRun.style?.fontFamily == nil)
        #expect(titleRun.style?.weightedFontFamily == nil)
    }

    /// A metrics body expands to native stat cards: a value(+unit) text and a label per metric, plus
    /// a track+fill bar only for metrics that carry a `ratio` (no image, no new element type).
    @Test func metricsExpandToValueLabelAndBar() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "実績", bodies: [
                SemanticBody(metrics: [
                    SemanticMetric(label: "継続率", value: "98", unit: "%", ratio: 0.98),
                    SemanticMetric(label: "導入企業", value: "1,200", unit: "社"),
                ]),
            ]),
        ]))
        let elements = try #require(p.slides?.first?.pageElements)
        let ids = elements.compactMap(\.objectId).filter { $0.contains("-metric-") }

        // Both metrics get a value + label.
        #expect(ids.contains("slide-1-metric-0-0-value"))
        #expect(ids.contains("slide-1-metric-0-0-label"))
        #expect(ids.contains("slide-1-metric-0-1-value"))
        #expect(ids.contains("slide-1-metric-0-1-label"))

        // Only the first metric (ratio: 0.98) draws a bar; the second (no ratio) does not.
        #expect(ids.contains("slide-1-metric-0-0-track"))
        #expect(ids.contains("slide-1-metric-0-0-fill"))
        #expect(!ids.contains("slide-1-metric-0-1-track"))

        // The value text carries the value and unit; the label carries its text.
        let valueRun = try #require(elements.first { $0.objectId == "slide-1-metric-0-0-value" }?
            .shape?.text?.textElements?.compactMap { $0.textRun?.content }.joined())
        #expect(valueRun.contains("98"))
        #expect(valueRun.contains("%"))

        // The fill bar is narrower than its track (ratio < 1).
        let track = try #require(elements.first { $0.objectId == "slide-1-metric-0-0-track" }?.size?.width?.magnitude)
        let fill = try #require(elements.first { $0.objectId == "slide-1-metric-0-0-fill" }?.size?.width?.magnitude)
        #expect(fill < track)
    }

    /// A chart body expands to a column chart: a bar + value + label per data point and a baseline,
    /// with bar heights proportional to value (the taller value yields the taller bar).
    @Test func chartExpandsToProportionalBars() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "成長", bodies: [
                SemanticBody(chart: SemanticChart(bars: [
                    SemanticChartBar(label: "2023", value: 50, caption: "¥0.5億"),
                    SemanticChartBar(label: "2024", value: 100, caption: "¥1.0億"),
                ])),
            ]),
        ]))
        let elements = try #require(p.slides?.first?.pageElements)
        let ids = elements.compactMap(\.objectId).filter { $0.contains("-chart-") }

        #expect(ids.contains("slide-1-chart-0-base"))
        for i in 0...1 {
            #expect(ids.contains("slide-1-chart-0-\(i)-bar"))
            #expect(ids.contains("slide-1-chart-0-\(i)-value"))
            #expect(ids.contains("slide-1-chart-0-\(i)-label"))
        }

        // The 100-value bar is taller than the 50-value bar (proportional heights).
        let bar0 = try #require(elements.first { $0.objectId == "slide-1-chart-0-0-bar" }?.size?.height?.magnitude)
        let bar1 = try #require(elements.first { $0.objectId == "slide-1-chart-0-1-bar" }?.size?.height?.magnitude)
        #expect(bar1 > bar0)
        #expect(abs(bar1 - 2 * bar0) < 1) // 100 vs 50 → ~2× height

        // The caption is printed above the bar.
        let valueText = try #require(elements.first { $0.objectId == "slide-1-chart-0-1-value" }?
            .shape?.text?.textElements?.compactMap { $0.textRun?.content }.joined())
        #expect(valueText.contains("¥1.0億"))
    }

    /// A line chart expands to markers + connecting segments + value/category labels (no bars). An
    /// ascending segment is encoded with a vertical flip (negative scaleY); a descending one isn't.
    @Test func lineChartExpandsWithFlippedAscendingSegments() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "推移", bodies: [
                SemanticBody(chart: SemanticChart(bars: [
                    SemanticChartBar(label: "2022", value: 30),
                    SemanticChartBar(label: "2023", value: 80),  // ascending vs 2022
                    SemanticChartBar(label: "2024", value: 50),  // descending vs 2023
                ], type: .line)),
            ]),
        ]))
        let elements = try #require(p.slides?.first?.pageElements)
        let ids = elements.compactMap(\.objectId).filter { $0.contains("-chart-") }

        #expect(ids.contains("slide-1-chart-0-base"))
        #expect(ids.contains("slide-1-chart-0-0-seg"))
        #expect(ids.contains("slide-1-chart-0-1-seg"))
        for i in 0...2 {
            #expect(ids.contains("slide-1-chart-0-\(i)-dot"))
            #expect(ids.contains("slide-1-chart-0-\(i)-value"))
            #expect(ids.contains("slide-1-chart-0-\(i)-label"))
        }
        #expect(!ids.contains { $0.hasSuffix("-bar") }) // a line chart draws no bars

        // 30→80 rises: vertical flip (scaleY < 0). 80→50 falls: no flip (scaleY > 0).
        let seg0 = try #require(elements.first { $0.objectId == "slide-1-chart-0-0-seg" })
        let seg1 = try #require(elements.first { $0.objectId == "slide-1-chart-0-1-seg" })
        #expect((seg0.transform?.scaleY ?? 1) < 0)
        #expect((seg1.transform?.scaleY ?? 1) > 0)

        // Markers render as ellipses.
        let dot = try #require(elements.first { $0.objectId == "slide-1-chart-0-0-dot" })
        #expect(dot.shape?.shapeType == .ellipse)
    }

    /// A steps body expands to a row of cards with labels joined by arrows: one card + label per step,
    /// an arrow between consecutive steps (n-1), and a caption only where provided.
    @Test func stepsExpandToCardsJoinedByArrows() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "流れ", bodies: [
                SemanticBody(steps: [
                    SemanticStep(label: "調査", caption: "現状を掴む"),
                    SemanticStep(label: "整理"),
                    SemanticStep(label: "実行"),
                ]),
            ]),
        ]))
        let elements = try #require(p.slides?.first?.pageElements)
        let ids = elements.compactMap(\.objectId).filter { $0.contains("-step-") }

        for i in 0...2 {
            #expect(ids.contains("slide-1-step-0-\(i)-card"))
            #expect(ids.contains("slide-1-step-0-\(i)-label"))
        }
        // Two arrows for three steps; only the first step has a caption.
        #expect(ids.filter { $0.hasSuffix("-arrow") }.count == 2)
        #expect(ids.contains("slide-1-step-0-0-caption"))
        #expect(!ids.contains("slide-1-step-0-1-caption"))

        // The connector is a filled right-arrow shape (reliable for a horizontal arrow).
        let arrow = try #require(elements.first { $0.objectId == "slide-1-step-0-0-arrow" })
        #expect(arrow.shape?.shapeType == .rightArrow)
        // Cards render as rounded rectangles.
        let card = try #require(elements.first { $0.objectId == "slide-1-step-0-0-card" })
        #expect(card.shape?.shapeType == .roundRectangle)
    }

    /// A quote body expands to a quotation mark, the quote text, and an attribution (only when an
    /// author/role is given).
    @Test func quoteExpandsToMarkTextAndAttribution() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "顧客の声", bodies: [
                SemanticBody(quote: SemanticQuote(text: "調査の時間が半分になった。", author: "山田太郎", role: "Acme 部長")),
            ]),
        ]))
        let elements = try #require(p.slides?.first?.pageElements)
        func runs(_ id: String) -> String? {
            elements.first { $0.objectId == id }?.shape?.text?.textElements?.compactMap { $0.textRun?.content }.joined()
        }

        let text = try #require(runs("slide-1-quote-0-text"))
        #expect(text.contains("調査の時間が半分になった"))
        let attr = try #require(runs("slide-1-quote-0-attr"))
        #expect(attr.contains("山田太郎"))
        #expect(attr.contains("Acme 部長"))
        #expect(elements.contains { $0.objectId == "slide-1-quote-0-mark" })

        // No author/role → no attribution element.
        let p2 = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "声", bodies: [SemanticBody(quote: SemanticQuote(text: "最高。"))]),
        ]))
        let ids2 = (p2.slides?.first?.pageElements ?? []).compactMap(\.objectId)
        #expect(!ids2.contains("slide-1-quote-0-attr"))
    }

    @Test func formatValueGroupsThousands() {
        #expect(PresentationExpander.formatValue(1200) == "1,200")
        #expect(PresentationExpander.formatValue(999) == "999")
        #expect(PresentationExpander.formatValue(1_234_567) == "1,234,567")
        #expect(PresentationExpander.formatValue(12.5) == "12.5")
        #expect(PresentationExpander.formatValue(1234.5) == "1,234.5")
    }

    @Test func layoutPagesReferenceMasterAndHavePlaceholders() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_TWO_COLUMNS", title: "T", bodies: [SemanticBody(text: "l"), SemanticBody(text: "r")]),
        ]))
        let layout = try #require(p.layouts?.first)
        #expect(layout.layoutProperties?.masterObjectId == PresentationTemplate.masterObjectId)
        let bodyIndices = (layout.pageElements ?? []).compactMap { $0.shape?.placeholder }.filter { $0.type == .body }.compactMap(\.index)
        #expect(Set(bodyIndices) == [0, 1])
    }

    @Test func slideReferencesTemplateMaster() {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [SemanticSlide(title: "A")]))
        #expect(p.slides?.first?.slideProperties?.masterObjectId == PresentationTemplate.masterObjectId)
    }
}

@Suite struct PresentationDecorationTests {
    func slide(_ layout: String) -> Page {
        PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: layout, title: "T", bodies: [SemanticBody(text: "b")]),
        ])).slides!.first!
    }

    @Test func contentSlidesHavePageNumberAndNoFloatingAccentBar() throws {
        let s = slide("TITLE_AND_BODY")  // title "T" has no "：" → single headline, no eyebrow
        // The floating accent rectangle is gone — the eyebrow kicker carries the accent now.
        let accent = (s.pageElements ?? []).first { $0.objectId.hasSuffix("-accent") }
        #expect(accent == nil)
        // page number footer remains
        let pageNo = (s.pageElements ?? []).first { $0.objectId.hasSuffix("-pageno") }
        #expect(pageNo?.shape?.text?.textElements?.first?.textRun?.content == "1")
    }

    @Test func labelTitleBecomesAccentEyebrowPlusHeadline() throws {
        let s = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "実績：日本最大級の基盤", bodies: [SemanticBody(text: "b")]),
        ])).slides!.first!
        let title = try #require((s.pageElements ?? []).first { $0.shape?.placeholder?.type == .title })
        let runs = (title.shape?.text?.textElements ?? []).compactMap(\.textRun)
        #expect(runs.count == 2)
        // eyebrow = the label, accent-colored
        #expect(runs.first?.content == "実績")
        #expect(runs.first?.style?.foregroundColor?.opaqueColor?.themeColor == .accent1)
        // headline = the conclusion
        #expect(runs.last?.content == "日本最大級の基盤")
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
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE", title: "T", subtitle: "s", bodies: [SemanticBody(imageUrl: "https://x/i.png")]),
        ]))
        #expect(!(p.slides!.first!.pageElements!).contains { $0.image != nil })
    }

    @Test func imageOnlyBodyFillsBodyArea() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [SemanticBody(imageUrl: "https://x/i.png")]),
        ]))
        let image = try #require(p.slides!.first!.pageElements!.first { $0.image != nil })
        #expect(image.size?.width?.magnitude != nil)
    }

    /// Regression: a model that splits bullets and image into SEPARATE bodies on a single-column
    /// layout must still get side-by-side columns, not two elements stacked in the same rect.
    @Test func separateTextAndImageBodiesDoNotOverlap() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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

@Suite struct PresentationThemeTests {
    /// The master `ColorScheme` must mirror a real `presentations.get` master: all 16
    /// `ThemeColorType`s present, every type ⊆ the discovery enum (knownValues).
    @Test func masterEnumeratesAll16ThemeColorTypesForBothThemes() throws {
        for spec in [ThemeSpec.light, ThemeSpec.dark] {
            let colors = try #require(PresentationTemplate.master(theme: spec).pageProperties?.colorScheme?.colors)
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
        func light1(_ spec: ThemeSpec) throws -> RgbColor {
            let colors = try #require(PresentationTemplate.master(theme: spec).pageProperties?.colorScheme?.colors)
            return try #require(colors.first { $0.type == .light1 }?.color)
        }
        // light theme canvas (light1) is near-white; dark theme canvas is near-black
        #expect(try light1(.light).red! > 0.9)
        #expect(try light1(.dark).red! < 0.2)
    }

    /// The design intent (ThemeSpec) bakes into the master, independent of content.
    @Test func themeSpecBakesIntoMaster() throws {
        let dark = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [SemanticSlide(title: "A")]), themeSpec: .dark)
        let canvas = try #require(dark.masters?.first?.pageProperties?.colorScheme?.colors?.first { $0.type == .light1 }?.color)
        #expect(canvas.red! < 0.2)
    }

    /// The content schema must NOT carry a theme field — theme is a separate, authoritative tool.
    @Test func contentSchemaHasNoThemeField() throws {
        let text = String(decoding: try GSlidesGenerationContract.jsonSchemaData(), as: UTF8.self)
        #expect(!text.contains("\"theme\""))
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
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
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

    @Test func examplePresentationWithTableAndNestingStillValidates() throws {
        // the worked example must round-trip through the validation sandwich
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
        #expect((presentation.slides?.count ?? 0) > 0)
        #expect(presentation.slides?.contains { ($0.pageElements ?? []).contains { $0.table != nil } } == true)
    }
}

@Suite struct InlineEmphasisTests {
    @Test func parsesBoldAndAccentRuns() {
        let runs = PresentationExpander.inlineRuns("通常 **太字** と ==強調== 終わり")
        #expect(runs.map(\.content) == ["通常 ", "太字", " と ", "強調", " 終わり"])
        #expect(runs[1].style?.bold == true)
        #expect(runs[1].style?.foregroundColor == nil)                       // bold only
        #expect(runs[3].style?.bold == true)
        #expect(runs[3].style?.foregroundColor?.opaqueColor?.themeColor == .accent1) // accent
    }

    @Test func plainTextIsSingleRun() {
        let runs = PresentationExpander.inlineRuns("emphasis なし")
        #expect(runs.count == 1)
        #expect(runs[0].style == nil)
    }

    @Test func emphasizedBulletExpandsToMultipleRunsOnOneParagraph() throws {
        let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [SemanticBody(bullets: ["**重要**な点"])]),
        ]))
        let body = try #require(p.slides?.first?.pageElements?.first { $0.shape?.placeholder?.type == .body })
        let elements = try #require(body.shape?.text?.textElements)
        // one paragraph: marker+first run, then run-only elements (no extra markers)
        #expect(elements.filter { $0.paragraphMarker != nil }.count == 1)
        #expect(elements.first?.textRun?.style?.bold == true)               // the emphasized span is bold
        #expect(elements.contains { $0.textRun?.content?.contains("な点") == true })
    }

    @Test func exampleWithEmphasisStillValidates() throws {
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
        #expect((presentation.slides?.count ?? 0) > 0)
        // the example's serialized JSON carries the markup for the model to learn from
        #expect(GSlidesGenerationContract.examplePresentationJSON().contains("**"))
        #expect(GSlidesGenerationContract.examplePresentationJSON().contains("=="))
    }
}

@Suite struct DesignSystemSwapTests {
    /// The body region is placed from the supplied `SpacingScale` — swapping the scale moves it, so a
    /// profile/theme can choose a denser or looser rhythm without touching the template.
    @Test func swappingSpacingScaleMovesBodyRegion() throws {
        func bodyTopY(_ design: SlideDesignSystem) throws -> Double {
            let p = PresentationExpander.expand(SemanticPresentation(title: "x", slides: [
                SemanticSlide(layout: "TITLE_AND_BODY", title: "T", bodies: [SemanticBody(text: "b")]),
            ]), design: design)
            let body = try #require(p.slides?.first?.pageElements?.first { $0.shape?.placeholder?.type == .body })
            return try #require(body.transform?.translateY)
        }
        // A taller header pushes the body down by exactly the same EMU delta (single source of truth).
        var dense = SpacingScale.content
        dense.headerHeight = SpacingScale.content.headerHeight + 500_000
        let standardY = try bodyTopY(.standard)
        let denseY = try bodyTopY(SlideDesignSystem(scale: dense))
        #expect(denseY == standardY + 500_000)
    }

    /// `.plain` header style renders a single-run headline even for a "ラベル：結論" title — no eyebrow —
    /// proving the header treatment is a swappable variant, not a hardcoded behavior.
    @Test func swappingHeaderStyleToPlainDropsEyebrow() throws {
        let semantic = SemanticPresentation(title: "x", slides: [
            SemanticSlide(layout: "TITLE_AND_BODY", title: "実績：日本最大級の基盤", bodies: [SemanticBody(text: "b")]),
        ])
        func titleRuns(_ design: SlideDesignSystem) throws -> [TextRun] {
            let s = PresentationExpander.expand(semantic, design: design).slides!.first!
            let title = try #require((s.pageElements ?? []).first { $0.shape?.placeholder?.type == .title })
            return (title.shape?.text?.textElements ?? []).compactMap(\.textRun)
        }
        // eyebrowHeadline → two runs (eyebrow + headline); plain → one run (the whole title)
        #expect(try titleRuns(.standard).count == 2)
        let plain = try titleRuns(SlideDesignSystem(headerStyle: .plain))
        #expect(plain.count == 1)
        #expect(plain.first?.content?.trimmingCharacters(in: .newlines) == "実績：日本最大級の基盤")
    }
}
