import Foundation

/// Vendored, pinned Google Slides API specification — the package's single source of truth.
///
/// `slides-api-discovery-v1.json` is the machine-readable discovery document (types + enums);
/// `constraints-catalog.yaml` captures the prose-only constraints (objectId regex, atomicity,
/// field masks, page-bounds) quoted verbatim from authoritative Google sources. Both are frozen
/// here so the build is hermetic and validation is reproducible; `SpecProvenanceTests` fails if
/// either drifts from the pinned revision. See `Resources/Spec/PROVENANCE.md`.
public enum GSlidesSpec {
    /// The discovery `revision` this build is pinned to. Bumped only by a human after running
    /// `scripts/fetch-discovery.sh` and reconciling `SpecProvenanceTests`.
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

    /// The user-supplied object ID rules, lifted verbatim from the discovery doc's
    /// `CreateShapeRequest.objectId` prose (see `constraints-catalog.yaml`, id `object-id-format`).
    /// This is the bridge from the frozen prose to the code that enforces it — kept in one place so
    /// the validator never re-states the rule from memory. `SpecProvenanceTests` asserts the
    /// discovery doc still carries this exact prose.
    public enum ObjectId {
        public static let minLength = 5
        public static let maxLength = 50
        /// Anchored regex: first char `[a-zA-Z0-9_]`, remaining `[a-zA-Z0-9_-:]`, total length 5–50.
        public static let pattern = "^[a-zA-Z0-9_][a-zA-Z0-9_:-]{4,49}$"

        /// Whether `id` satisfies the API's documented object-ID format (length + charset).
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
