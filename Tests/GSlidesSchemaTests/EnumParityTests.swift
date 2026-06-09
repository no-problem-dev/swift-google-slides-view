import Foundation
import Testing
@testable import GSlidesSchema

/// Every SpecEnum's known values must EQUAL the corresponding enum in the vendored discovery
/// document — the model is a complete, exact mirror (no invented values, no missing values).
@Suite struct EnumParityTests {
    static let registry: [(values: [String], schema: String, property: String)] = [
        (Unit.knownValues.map(\.rawValue), "Dimension", "unit"),
        (ThemeColorType.knownValues.map(\.rawValue), "OpaqueColor", "themeColor"),
        (Alignment.knownValues.map(\.rawValue), "ParagraphStyle", "alignment"),
        (TextDirection.knownValues.map(\.rawValue), "ParagraphStyle", "direction"),
        (SpacingMode.knownValues.map(\.rawValue), "ParagraphStyle", "spacingMode"),
        (BaselineOffset.knownValues.map(\.rawValue), "TextStyle", "baselineOffset"),
        (PageType.knownValues.map(\.rawValue), "Page", "pageType"),
        (PlaceholderType.knownValues.map(\.rawValue), "Placeholder", "type"),
        (ShapeType.knownValues.map(\.rawValue), "Shape", "shapeType"),
        (AutofitType.knownValues.map(\.rawValue), "Autofit", "autofitType"),
        (PredefinedLayout.knownValues.map(\.rawValue), "LayoutReference", "predefinedLayout"),
        (PropertyState.knownValues.map(\.rawValue), "Outline", "propertyState"),
        (DashStyle.knownValues.map(\.rawValue), "Outline", "dashStyle"),
        (ShadowType.knownValues.map(\.rawValue), "Shadow", "type"),
        (RectanglePosition.knownValues.map(\.rawValue), "Shadow", "alignment"),
        (RecolorName.knownValues.map(\.rawValue), "Recolor", "name"),
        (ContentAlignment.knownValues.map(\.rawValue), "ShapeProperties", "contentAlignment"),
        (AutoTextType.knownValues.map(\.rawValue), "AutoText", "type"),
        (ArrowStyle.knownValues.map(\.rawValue), "LineProperties", "startArrow"),
        (LineType.knownValues.map(\.rawValue), "Line", "lineType"),
        (LineCategory.knownValues.map(\.rawValue), "Line", "lineCategory"),
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
    func knownValuesEqualDiscovery(index: Int) throws {
        let entry = Self.registry[index]
        let discovery = try Self.discoveryEnum(schema: entry.schema, property: entry.property)
        let ours = Set(entry.values)
        #expect(ours.subtracting(discovery).isEmpty, "\(entry.schema).\(entry.property): invented values \(ours.subtracting(discovery))")
        #expect(discovery.subtracting(ours).isEmpty, "\(entry.schema).\(entry.property): MISSING values \(discovery.subtracting(ours))")
    }

    @Test func knownValuesAreUniquePerType() {
        for entry in Self.registry {
            #expect(Set(entry.values).count == entry.values.count)
        }
    }
}
