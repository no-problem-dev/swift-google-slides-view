import Foundation
import Testing
@testable import GSlidesSchema

@Suite struct RoundTripTests {
    func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func roundTrip(_ name: String) throws -> (first: Presentation, second: Presentation) {
        let decoder = JSONDecoder()
        let first = try decoder.decode(Presentation.self, from: fixture(name))
        let encoded = try JSONEncoder().encode(first)
        let second = try decoder.decode(Presentation.self, from: encoded)
        return (first, second)
    }

    @Test func blankPresentationRoundTrips() throws {
        let (first, second) = try roundTrip("blank_presentation")
        #expect(first == second)
        #expect(first.pageSize?.width?.magnitude == 9_144_000)
        #expect(first.pageSize?.height?.magnitude == 5_143_500)
        #expect(first.layouts?.isEmpty == false)
        #expect(first.masters?.isEmpty == false)
    }

    @Test func mockPresentationRoundTrips() throws {
        let (first, second) = try roundTrip("mock_presentation")
        #expect(first == second)
        #expect(first.slides?.count == 3)
    }

    @Test func placeholdersDecodeFromMock() throws {
        let (first, _) = try roundTrip("mock_presentation")
        let elements = try #require(first.slides?.first?.pageElements)
        let placeholderTypes = elements.compactMap { $0.shape?.placeholder?.type }
        #expect(placeholderTypes.contains(.centeredTitle))
    }

    @Test func predefinedLayoutsResolveInBlankFixture() throws {
        let (first, _) = try roundTrip("blank_presentation")
        let names = Set((first.layouts ?? []).compactMap(\.layoutProperties?.name))
        let known = Set(PredefinedLayout.knownValues.map(\.rawValue))
        #expect(!names.isDisjoint(with: known), "no layout names overlap predefined layouts: \(names)")
    }

    @Test func outOfProfileUnionMemberIsUnknown() throws {
        // A future/unmodeled union member (none of the known element fields present).
        let json = """
        {"objectId": "x", "someFutureElement": {"foo": "bar"}}
        """
        let element = try JSONDecoder().decode(PageElement.self, from: Data(json.utf8))
        #expect(element.kind == .unknown)
    }

    @Test func unknownEnumValueRoundTripsLosslessly() throws {
        // A future value not in the (now complete) discovery mirror still survives decode→encode.
        let json = """
        {"shapeType": "SOME_FUTURE_SHAPE_9999"}
        """
        let shape = try JSONDecoder().decode(Shape.self, from: Data(json.utf8))
        #expect(shape.shapeType?.rawValue == "SOME_FUTURE_SHAPE_9999")
        #expect(ShapeType.knownValues.contains(shape.shapeType!) == false)
        let encoded = try JSONEncoder().encode(shape)
        let again = try JSONDecoder().decode(Shape.self, from: encoded)
        #expect(again.shapeType?.rawValue == "SOME_FUTURE_SHAPE_9999")
    }

    @Test func discoveryShapeTypeIsNowKnown() {
        // FLOW_CHART_DECISION is a real discovery value — the complete mirror knows it.
        #expect(ShapeType.knownValues.contains(ShapeType(rawValue: "FLOW_CHART_DECISION")))
    }
}

@Suite struct FullModelRoundTripTests {
    func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @Test func decoratedShapeRoundTrips() throws {
        let shape = Shape(
            shapeType: .roundRectangle,
            text: TextContent(
                textElements: [TextElement(textRun: TextRun(content: "hi", style: TextStyle(
                    weightedFontFamily: WeightedFontFamily(fontFamily: "Roboto", weight: 700),
                    link: Link(url: "https://example.com"))))],
                lists: ["L1": List(listId: "L1", nestingLevel: ["0": NestingLevel(bulletStyle: TextStyle(bold: true))])]
            ),
            shapeProperties: ShapeProperties(
                shadow: Shadow(type: .outer, alignment: .bottomRight, blurRadius: Dimension(magnitude: 5, unit: .pt),
                               color: OpaqueColor(themeColor: .dark1), alpha: 0.4, propertyState: .rendered),
                link: Link(slideIndex: 2),
                contentAlignment: .middle
            )
        )
        #expect(try roundTrip(shape) == shape)
    }

    @Test func imagePropertiesRoundTrip() throws {
        let image = Image(
            contentUrl: "https://x/y.png",
            imageProperties: ImageProperties(
                cropProperties: CropProperties(leftOffset: 0.1, angle: 0.2),
                brightness: 0.3,
                recolor: Recolor(recolorStops: [ColorStop(color: OpaqueColor(themeColor: .accent1), position: 0.5)], name: .grayscale),
                outline: Outline(weight: Dimension(magnitude: 1, unit: .pt), dashStyle: .dash, propertyState: .rendered)
            )
        )
        #expect(try roundTrip(image) == image)
    }

    @Test func unionMembersAreFirstClass() throws {
        for (json, expected) in [
            (#"{"objectId":"v","video":{"url":"https://v","source":"YOUTUBE","videoProperties":{"autoPlay":true}}}"#, "video"),
            (#"{"objectId":"w","wordArt":{"renderedText":"ART"}}"#, "wordArt"),
            (#"{"objectId":"c","sheetsChart":{"spreadsheetId":"s","chartId":3,"contentUrl":"u"}}"#, "sheetsChart"),
            (#"{"objectId":"s","speakerSpotlight":{"speakerSpotlightProperties":{}}}"#, "speakerSpotlight"),
        ] {
            let element = try JSONDecoder().decode(PageElement.self, from: Data(json.utf8))
            switch (element.kind, expected) {
            case (.video, "video"), (.wordArt, "wordArt"), (.sheetsChart, "sheetsChart"), (.speakerSpotlight, "speakerSpotlight"):
                break
            default:
                Issue.record("\(expected) did not map to its first-class kind: \(element.kind)")
            }
        }
    }

    @Test func colorSchemeResolvesThemeColor() {
        let scheme = ColorScheme(colors: [
            ThemeColorPair(type: .accent1, color: RgbColor(red: 0.2, green: 0.5, blue: 0.9)),
            ThemeColorPair(type: .dark1, color: RgbColor(red: 0.1, green: 0.1, blue: 0.1)),
        ])
        #expect(scheme.rgb(for: .accent1)?.blue == 0.9)
        #expect(scheme.rgb(for: .background1) == nil)
    }

    @Test func notesPageRecursiveRoundTrips() throws {
        let slide = Page(
            objectId: "slide-1",
            pageType: .slide,
            slideProperties: SlideProperties(
                layoutObjectId: "L",
                notesPage: Page(objectId: "notes-1", pageType: .notes,
                                notesProperties: NotesProperties(speakerNotesObjectId: "notes-shape"))
            )
        )
        let back = try roundTrip(slide)
        #expect(back == slide)
        #expect(back.slideProperties?.notesPage?.value.objectId == "notes-1")
    }
}

@Suite struct ParagraphStyleConformanceTests {
    @Test func directionAndSpacingModeDecodeAndRoundTrip() throws {
        let json = #"{"alignment":"END","direction":"RIGHT_TO_LEFT","spacingMode":"COLLAPSE_LISTS","lineSpacing":150}"#
        let style = try JSONDecoder().decode(ParagraphStyle.self, from: Data(json.utf8))
        #expect(style.direction == .rightToLeft)
        #expect(style.spacingMode == .collapseLists)
        let again = try JSONDecoder().decode(ParagraphStyle.self, from: JSONEncoder().encode(style))
        #expect(again == style)
    }

    @Test func fullParagraphStyleRoundTrips() throws {
        let style = ParagraphStyle(
            alignment: .justified, lineSpacing: 115,
            indentStart: Dimension(magnitude: 18, unit: .pt), indentEnd: Dimension(magnitude: 9, unit: .pt),
            indentFirstLine: Dimension(magnitude: 36, unit: .pt), spaceAbove: Dimension(magnitude: 6, unit: .pt),
            spaceBelow: Dimension(magnitude: 6, unit: .pt), direction: .leftToRight, spacingMode: .neverCollapse)
        let data = try JSONEncoder().encode(style)
        #expect(try JSONDecoder().decode(ParagraphStyle.self, from: data) == style)
    }
}

@Suite struct CompleteSchemaTests {
    func roundTrip<T: Codable & Equatable>(_ v: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(v))
    }

    @Test func lineWithTypeCategoryAndConnectionsRoundTrips() throws {
        let line = Line(
            lineProperties: LineProperties(
                weight: Dimension(magnitude: 2, unit: .pt),
                startArrow: .fillArrow, endArrow: .openCircle,
                startConnection: LineConnection(connectedObjectId: "shape-1", connectionSiteIndex: 0),
                endConnection: LineConnection(connectedObjectId: "shape-2", connectionSiteIndex: 3)),
            lineType: .bentConnector3, lineCategory: .bent)
        #expect(try roundTrip(line) == line)
    }

    @Test func tableWithBordersRoundTrips() throws {
        let border = TableBorderProperties(
            tableBorderFill: TableBorderFill(solidFill: SolidFill(color: OpaqueColor(themeColor: .dark2))),
            weight: Dimension(magnitude: 1, unit: .pt), dashStyle: .solid)
        let table = Table(
            rows: 1, columns: 1,
            tableRows: [TableRow(tableCells: [TableCell(text: TextContent(textElements: []))])],
            horizontalBorderRows: [TableBorderRow(tableBorderCells: [TableBorderCell(location: TableCellLocation(rowIndex: 0, columnIndex: 0), tableBorderProperties: border)])],
            verticalBorderRows: [TableBorderRow(tableBorderCells: [TableBorderCell(tableBorderProperties: border)])])
        #expect(try roundTrip(table) == table)
    }

    @Test func thumbnailDecodes() throws {
        let t = try JSONDecoder().decode(Thumbnail.self, from: Data(#"{"width":1600,"height":900,"contentUrl":"https://t/x.png"}"#.utf8))
        #expect(t.width == 1600 && t.height == 900)
    }
}
