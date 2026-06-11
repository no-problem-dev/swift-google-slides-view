import Foundation
import Testing
@testable import GSlidesSchema

/// Drift guard for the vendored spec. The discovery doc is the SSOT, but the `PreflightValidator`
/// also depends on prose constraints (objectId regex, batch atomicity, write control) quoted in
/// `constraints-catalog.yaml`. If Google changes the pinned revision or that wording, these tests
/// fail and force a human to re-derive the affected rule — the spec must never drift silently.
@Suite struct SpecProvenanceTests {
    func discoveryString() throws -> String {
        String(decoding: try GSlidesSpec.discoveryDocument(), as: UTF8.self)
    }

    @Test func discoveryRevisionMatchesPin() throws {
        let json = try JSONSerialization.jsonObject(with: try GSlidesSpec.discoveryDocument()) as? [String: Any]
        #expect(json?["revision"] as? String == GSlidesSpec.pinnedRevision)
    }

    @Test func objectIdProseIsUnchanged() throws {
        // The exact sentence GSlidesSpec.ObjectId is derived from. If this fails, the regex/bounds
        // in code may no longer match the API — re-derive before re-pinning.
        let doc = try discoveryString()
        #expect(doc.contains("must start with an alphanumeric character or an underscore (matches regex `[a-zA-Z0-9_]`)"))
        #expect(doc.contains("The length of the ID must not be less than 5 or greater than 50"))
    }

    @Test func batchAtomicityProseIsUnchanged() throws {
        let doc = try discoveryString()
        #expect(doc.contains("If any request is not valid, then the entire request will fail and nothing will be applied"))
    }

    @Test func writeControlProseIsUnchanged() throws {
        let doc = try discoveryString()
        #expect(doc.contains("doesn't match the presentation's current revision ID, the request is not processed and returns a 400 bad request error"))
    }

    @Test func sharedNamespaceProseIsUnchanged() throws {
        let doc = try discoveryString()
        #expect(doc.contains("share the same namespace"))
    }

    @Test func constraintsCatalogIsBundledAndPinnedToSameRevision() throws {
        let catalog = try GSlidesSpec.constraintsCatalog()
        #expect(catalog.contains("discovery_revision: \"\(GSlidesSpec.pinnedRevision)\""))
        #expect(catalog.contains("id: object-id-format"))
        #expect(catalog.contains("id: page-bounds"))
        #expect(catalog.contains("id: theme-color-scheme-editable"))
    }

    @Test func themeColorSchemeProseIsUnchanged() throws {
        // The exact sentence ThemeColorType.editableSlots and the theme conformance rules derive from.
        let doc = try discoveryString()
        #expect(doc.contains("Only the concrete colors of the first 12 ThemeColorTypes are editable"))
        #expect(doc.contains("only the color scheme on `Master` pages can be updated"))
    }

    @Test func rgbColorRangeProseIsUnchanged() throws {
        #expect(try discoveryString().contains("The red component of the color, from 0.0 to 1.0"))
    }

    /// `ThemeColorType.editableSlots` must equal the discovery `ThemeColorType` enum's first 12
    /// values (after the UNSPECIFIED sentinel) — the spec's "first 12 ThemeColorTypes". If Google
    /// reorders or extends the enum, this fails and forces a human to re-derive the editable set.
    @Test func editableSlotsMatchDiscoveryFirstTwelve() throws {
        let root = try JSONSerialization.jsonObject(with: try GSlidesSpec.discoveryDocument()) as? [String: Any]
        let schemas = try #require(root?["schemas"] as? [String: Any])
        let pair = try #require(schemas["ThemeColorPair"] as? [String: Any])
        let props = try #require(pair["properties"] as? [String: Any])
        let typeProp = try #require(props["type"] as? [String: Any])
        let values = try #require(typeProp["enum"] as? [String])
        // Drop the leading THEME_COLOR_TYPE_UNSPECIFIED sentinel, take the first 12.
        let firstTwelve = Array(values.dropFirst().prefix(12))
        #expect(ThemeColorType.editableSlots.map(\.rawValue) == firstTwelve)
    }

    @Test func objectIdValidatorMatchesTheProse() {
        // Charset + length, exactly as the pinned prose states.
        #expect(GSlidesSpec.ObjectId.isValid("title_1"))
        #expect(GSlidesSpec.ObjectId.isValid("a:b-c_2"))
        #expect(!GSlidesSpec.ObjectId.isValid("abc"))                 // < 5
        #expect(!GSlidesSpec.ObjectId.isValid("-leading"))            // first char not [a-zA-Z0-9_]
        #expect(!GSlidesSpec.ObjectId.isValid("has space"))           // space not allowed
        #expect(!GSlidesSpec.ObjectId.isValid(String(repeating: "a", count: 51)))  // > 50
    }
}
