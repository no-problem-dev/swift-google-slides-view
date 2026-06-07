import Foundation

/// Vendored Google Slides API discovery document (pinned SSOT for schema conformance).
public enum GSlidesSpec {
    public static var discoveryDocumentURL: URL {
        Bundle.module.url(forResource: "Spec/slides-api-discovery-v1", withExtension: "json")!
    }

    public static func discoveryDocument() throws -> Data {
        try Data(contentsOf: discoveryDocumentURL)
    }
}
