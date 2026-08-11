import Foundation

/// The vendored, pinned Google Slides API specification the whole package is derived from.
///
/// `slides-api-discovery-v1.json` is the machine-readable discovery document (types and enums).
/// `constraints-catalog.yaml` quotes verbatim the constraints that exist only as prose — objectId
/// format, batch atomicity, field-mask semantics, page bounds. Both files are frozen here so builds
/// reproduce and validation does not drift; `SpecProvenanceTests` fails if either stops matching the
/// pinned revision. See `Resources/Spec/PROVENANCE.md`.
public enum GSlidesSpec {
    /// The discovery-document revision this build is pinned to.
    ///
    /// Bumped by hand, after running `scripts/fetch-discovery.sh` and reconciling the result with
    /// `SpecProvenanceTests`. Nothing updates it automatically.
    public static let pinnedRevision = "20260601"

    public static var discoveryDocumentURL: URL {
        Bundle.module.url(forResource: "Spec/slides-api-discovery-v1", withExtension: "json")!
    }

    public static func discoveryDocument() throws -> Data {
        try Data(contentsOf: discoveryDocumentURL)
    }

    public static var constraintsCatalogURL: URL {
        Bundle.module.url(forResource: "Spec/constraints-catalog", withExtension: "yaml")!
    }

    public static func constraintsCatalog() throws -> String {
        String(decoding: try Data(contentsOf: constraintsCatalogURL), as: UTF8.self)
    }

    /// The format rules for caller-supplied object IDs, quoted from the discovery document's
    /// `CreateShapeRequest.objectId` prose (catalog: object-id-format).
    ///
    /// Kept in one place so validators never restate the rule from memory. `SpecProvenanceTests`
    /// checks that the frozen prose still matches the discovery document exactly.
    public enum ObjectId {
        public static let minLength = 5
        public static let maxLength = 50
        /// Anchored regex: first character `[a-zA-Z0-9_]`, the rest `[a-zA-Z0-9_:-]`, total length 5–50.
        ///
        /// Provided for callers that want the literal pattern; `isValid(_:)` applies the same rule
        /// without a regex engine.
        public static let pattern = "^[a-zA-Z0-9_][a-zA-Z0-9_:-]{4,49}$"

        /// Whether `id` satisfies the API's object ID format.
        ///
        /// Checks length and character set only. Uniqueness across a presentation is a separate
        /// constraint the preflight validator enforces.
        public static func isValid(_ id: String) -> Bool {
            guard id.count >= minLength, id.count <= maxLength else { return false }
            guard let first = id.first, first == "_" || first.isASCII && first.isLetter || first.isNumber
            else { return false }
            return id.allSatisfy { c in
                c == "_" || c == "-" || c == ":" || (c.isASCII && (c.isLetter || c.isNumber))
            }
        }
    }
}
