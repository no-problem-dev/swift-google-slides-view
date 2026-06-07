import Foundation
import Testing
@testable import GSlidesSchema

@Suite struct SpecResourceTests {
    @Test func discoveryDocumentIsBundledAndParses() throws {
        let data = try GSlidesSpec.discoveryDocument()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let schemas = try #require(json?["schemas"] as? [String: Any])
        #expect(schemas.count > 100)
    }

    @Test func goldenFixturesParse() throws {
        for name in ["blank_presentation", "mock_presentation"] {
            let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            #expect(json is [String: Any])
        }
    }
}
