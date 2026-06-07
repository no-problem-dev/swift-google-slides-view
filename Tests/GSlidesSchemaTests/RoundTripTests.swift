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

    @Test func unknownUnionMemberIsFirstClass() throws {
        let json = """
        {"objectId": "x", "video": {"url": "https://example.com"}}
        """
        let element = try JSONDecoder().decode(PageElement.self, from: Data(json.utf8))
        #expect(element.kind == .unknown)
    }

    @Test func outOfProfileEnumValueRoundTrips() throws {
        let json = """
        {"shapeType": "FLOW_CHART_DECISION"}
        """
        let shape = try JSONDecoder().decode(Shape.self, from: Data(json.utf8))
        #expect(shape.shapeType?.rawValue == "FLOW_CHART_DECISION")
        #expect(ShapeType.knownValues.contains(shape.shapeType!) == false)
        let encoded = try JSONEncoder().encode(shape)
        let again = try JSONDecoder().decode(Shape.self, from: encoded)
        #expect(again.shapeType?.rawValue == "FLOW_CHART_DECISION")
    }
}
