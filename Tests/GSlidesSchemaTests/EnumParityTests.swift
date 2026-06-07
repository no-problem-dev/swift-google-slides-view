import Foundation
import Testing
@testable import GSlidesSchema

/// Every SpecEnum's known values must be a subset of the corresponding enum in the
/// vendored discovery document — the profile never invents vocabulary.
@Suite struct EnumParityTests {
    static let registry: [(values: [String], schema: String, property: String)] = [
        (Unit.knownValues.map(\.rawValue), "Dimension", "unit"),
        (ThemeColorType.knownValues.map(\.rawValue), "OpaqueColor", "themeColor"),
        (Alignment.knownValues.map(\.rawValue), "ParagraphStyle", "alignment"),
        (BaselineOffset.knownValues.map(\.rawValue), "TextStyle", "baselineOffset"),
        (PageType.knownValues.map(\.rawValue), "Page", "pageType"),
        (PlaceholderType.knownValues.map(\.rawValue), "Placeholder", "type"),
        (ShapeType.knownValues.map(\.rawValue), "Shape", "shapeType"),
        (AutofitType.knownValues.map(\.rawValue), "Autofit", "autofitType"),
        (PredefinedLayout.knownValues.map(\.rawValue), "LayoutReference", "predefinedLayout"),
    ]

    static func discoveryEnum(schema: String, property: String) throws -> Set<String> {
        let data = try GSlidesSpec.discoveryDocument()
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schemas = try #require(root["schemas"] as? [String: Any])
        let schemaObject = try #require(schemas[schema] as? [String: Any], "schema \(schema) missing")
        let properties = try #require(schemaObject["properties"] as? [String: Any])
        let propertyObject = try #require(properties[property] as? [String: Any], "property \(property) missing")
        let values = try #require(propertyObject["enum"] as? [String], "\(schema).\(property) has no enum")
        return Set(values)
    }

    @Test(arguments: registry.indices)
    func knownValuesAreSubsetOfDiscovery(index: Int) throws {
        let entry = Self.registry[index]
        let discovery = try Self.discoveryEnum(schema: entry.schema, property: entry.property)
        let unknown = Set(entry.values).subtracting(discovery)
        #expect(unknown.isEmpty, "\(entry.schema).\(entry.property): invented values \(unknown)")
    }

    @Test func knownValuesAreUniquePerType() {
        for entry in Self.registry {
            #expect(Set(entry.values).count == entry.values.count)
        }
    }
}
