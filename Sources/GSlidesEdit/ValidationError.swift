import Foundation

/// Why a single field of a batchUpdate request is rejected. Mirrors the `reason` identifier on
/// `google.rpc.BadRequest.FieldViolation` (SCREAMING_SNAKE_CASE, machine-stable) so an agent — or a
/// host relaying to one — can branch on the cause without parsing prose. Each case maps to a
/// constraint in `Resources/Spec/constraints-catalog.yaml`.
public enum ViolationReason: String, Equatable, Sendable, Codable, CaseIterable {
    /// A Request had no sub-request set (empty `kind` union). (catalog: request-exactly-one-kind)
    case emptyRequest = "EMPTY_REQUEST"
    /// A Request set more than one sub-request. (catalog: request-exactly-one-kind)
    case multipleKindsInRequest = "MULTIPLE_KINDS_IN_REQUEST"
    /// A required field (objectId, text, transform…) was missing.
    case requiredFieldMissing = "REQUIRED_FIELD_MISSING"
    /// A referenced objectId doesn't exist in the presentation. (catalog: object-reference-existence)
    case objectNotFound = "OBJECT_NOT_FOUND"
    /// A user-supplied objectId violates the charset/length rule. (catalog: object-id-format)
    case invalidObjectId = "INVALID_OBJECT_ID"
    /// A user-supplied objectId collides with an existing one. (catalog: object-id-uniqueness)
    case duplicateObjectId = "DUPLICATE_OBJECT_ID"
    /// An enum field carries a value the discovery document doesn't define. (catalog: enum-values-closed)
    case unknownEnumValue = "UNKNOWN_ENUM_VALUE"
    /// A `fields` mask is malformed (empty token, or `*` mixed with paths). (catalog: field-mask-semantics)
    case invalidFieldMask = "INVALID_FIELD_MASK"
    /// A text range is inverted or negative.
    case invalidTextRange = "INVALID_TEXT_RANGE"
    /// The element would end up entirely off the slide. (catalog: page-bounds)
    case outOfPageBounds = "OUT_OF_PAGE_BOUNDS"
    /// A transform collapses the element (scaleX or scaleY == 0). (catalog: degenerate-transform)
    case degenerateTransform = "DEGENERATE_TRANSFORM"
    /// The operation isn't permitted for this edit session (host policy via `allowing:`).
    case operationNotPermitted = "OPERATION_NOT_PERMITTED"
    /// A request kind the local reducer doesn't execute (out of the curated subset).
    case unsupportedOperation = "UNSUPPORTED_OPERATION"
}

/// One field-level reason a batchUpdate request can't be applied — the package's mirror of
/// `google.rpc.BadRequest.FieldViolation`. `field` is a dotted path into the batch
/// (`requests[2].updatePageElementTransform.objectId`) so an agent can locate and fix exactly the
/// offending value; `description` is the human/LLM-facing explanation; `reason` is the stable code.
public struct FieldViolation: Error, Equatable, Sendable, Codable {
    public var field: String
    public var description: String
    public var reason: ViolationReason

    public init(field: String, description: String, reason: ViolationReason) {
        self.field = field
        self.description = description
        self.reason = reason
    }

    /// Re-root this violation's `field` path under a batch index, e.g. `updatePageElementTransform.objectId`
    /// → `requests[2].updatePageElementTransform.objectId`. Used to lift a reducer-local violation
    /// into batch coordinates.
    func prefixed(byRequestIndex index: Int) -> FieldViolation {
        FieldViolation(field: "requests[\(index)].\(field)", description: description, reason: reason)
    }
}

/// The error thrown when a batchUpdate is rejected — the package's mirror of `google.rpc.Status`
/// carrying a `BadRequest` detail. Because batchUpdate is atomic ("if any request is not valid, the
/// entire request will fail and nothing will be applied"), a rejected batch applies NOTHING; this
/// error reports every field violation found so an agent can fix them in one pass rather than
/// discovering them one server round-trip at a time.
public struct BatchUpdateError: Error, Equatable, Sendable, Codable {
    /// HTTP-style status code Google returns for these failures.
    public var code: Int
    /// Canonical status string (`INVALID_ARGUMENT`, `FAILED_PRECONDITION`).
    public var status: String
    /// Developer-facing summary.
    public var message: String
    /// Every field-level violation (the `BadRequest.fieldViolations` detail).
    public var fieldViolations: [FieldViolation]

    public init(code: Int, status: String, message: String, fieldViolations: [FieldViolation]) {
        self.code = code
        self.status = status
        self.message = message
        self.fieldViolations = fieldViolations
    }

    /// Build an `INVALID_ARGUMENT` (HTTP 400) failure from a non-empty violation list — the shape
    /// Google returns when request validation fails before anything is applied.
    public static func invalidArgument(_ violations: [FieldViolation]) -> BatchUpdateError {
        let summary = violations.count == 1
            ? violations[0].description
            : "\(violations.count) request(s) were invalid; nothing was applied."
        return BatchUpdateError(code: 400, status: "INVALID_ARGUMENT", message: summary,
                                fieldViolations: violations)
    }

    /// A malformed request body (not valid JSON, or not a recognizable batch). HTTP 400, no field
    /// violations — the body couldn't be parsed into requests at all.
    public static func invalidJSON(_ detail: String) -> BatchUpdateError {
        BatchUpdateError(code: 400, status: "INVALID_ARGUMENT",
                         message: "Request body is not a valid batchUpdate JSON: \(detail)",
                         fieldViolations: [])
    }

    /// The full error rendered as Google's wire JSON (`{"error":{code,status,message,details:[…]}}`),
    /// suitable to hand back to an agent verbatim for self-correction.
    public func wireJSON() -> String {
        let details: [[String: Any]] = [[
            "@type": "type.googleapis.com/google.rpc.BadRequest",
            "fieldViolations": fieldViolations.map {
                ["field": $0.field, "description": $0.description, "reason": $0.reason.rawValue]
            },
        ]]
        let payload: [String: Any] = ["error": [
            "code": code, "status": status, "message": message, "details": details,
        ]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
        else { return "{\"error\":{\"status\":\"\(status)\",\"message\":\"\(message)\"}}" }
        return String(decoding: data, as: UTF8.self)
    }
}
