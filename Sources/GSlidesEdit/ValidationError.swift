import Foundation

/// Why one field of a batchUpdate request was rejected, as a machine-stable identifier.
///
/// Mirrors the `reason` identifiers of `google.rpc.BadRequest.FieldViolation` in SCREAMING_SNAKE_CASE
/// so an agent or a relaying host can branch on the cause without parsing prose. Each case maps to a
/// constraint in `Resources/Spec/constraints-catalog.yaml`.
public enum ViolationReason: String, Equatable, Sendable, Codable, CaseIterable {
    /// No sub-request is set — the `kind` union is empty. (catalog: request-exactly-one-kind)
    case emptyRequest = "EMPTY_REQUEST"
    /// More than one sub-request is set. (catalog: request-exactly-one-kind)
    case multipleKindsInRequest = "MULTIPLE_KINDS_IN_REQUEST"
    /// A field the operation cannot run without — objectId, text, transform — is absent.
    case requiredFieldMissing = "REQUIRED_FIELD_MISSING"
    /// The referenced objectId is not in the presentation. (catalog: object-reference-existence)
    case objectNotFound = "OBJECT_NOT_FOUND"
    /// A caller-supplied objectId breaks the character-set or length rule. (catalog: object-id-format)
    case invalidObjectId = "INVALID_OBJECT_ID"
    /// A caller-supplied objectId collides with an existing one. (catalog: object-id-uniqueness)
    case duplicateObjectId = "DUPLICATE_OBJECT_ID"
    /// An enum field holds a value the pinned discovery document does not define.
    /// (catalog: enum-values-closed)
    case unknownEnumValue = "UNKNOWN_ENUM_VALUE"
    /// The `fields` mask is malformed: an empty token, or `*` mixed with paths.
    /// (catalog: field-mask-semantics)
    case invalidFieldMask = "INVALID_FIELD_MASK"
    /// A text range is inverted or negative.
    case invalidTextRange = "INVALID_TEXT_RANGE"
    /// The element would end up entirely off the slide. (catalog: page-bounds)
    case outOfPageBounds = "OUT_OF_PAGE_BOUNDS"
    /// The transform collapses the element: scaleX or scaleY is exactly 0.
    /// (catalog: degenerate-transform)
    case degenerateTransform = "DEGENERATE_TRANSFORM"
    /// The host's `allowing:` policy excludes this operation from the edit session.
    case operationNotPermitted = "OPERATION_NOT_PERMITTED"
    /// The local reducer does not execute this request kind — it is outside the curated subset.
    case unsupportedOperation = "UNSUPPORTED_OPERATION"
}

/// One field-level reason a batchUpdate cannot be applied — this package's mirror of
/// `google.rpc.BadRequest.FieldViolation`.
///
/// `field` is a dotted path into the batch, such as
/// `requests[2].updatePageElementTransform.objectId`, so an agent can locate and fix the exact
/// value. `description` is prose for a human or a model; `reason` is the stable code to branch on.
public struct FieldViolation: Error, Equatable, Sendable, Codable {
    public var field: String
    public var description: String
    public var reason: ViolationReason

    public init(field: String, description: String, reason: ViolationReason) {
        self.field = field
        self.description = description
        self.reason = reason
    }

    /// Re-roots this violation's `field` path under a batch index.
    ///
    /// `updatePageElementTransform.objectId` becomes `requests[2].updatePageElementTransform.objectId`.
    ///
    /// Lifts a reducer-local violation into batch coordinates. Applying it twice nests the prefix,
    /// so call it once per violation.
    func prefixed(byRequestIndex index: Int) -> FieldViolation {
        FieldViolation(field: "requests[\(index)].\(field)", description: description, reason: reason)
    }
}

/// The error thrown when a batchUpdate is rejected — this package's mirror of `google.rpc.Status`
/// with a `BadRequest` detail.
///
/// A rejected batch applies nothing: batchUpdate is atomic, so one invalid request fails the whole
/// batch. Every violation found is reported at once rather than just the first, which is what lets
/// an agent fix everything in one pass instead of one server round trip per mistake.
public struct BatchUpdateError: Error, Equatable, Sendable, Codable {
    /// The HTTP-style status code Google returns for this class of failure.
    public var code: Int
    /// The canonical status string, such as `INVALID_ARGUMENT` or `FAILED_PRECONDITION`.
    public var status: String
    /// A developer-facing summary. For a single violation this is that violation's description;
    /// for several it is a count, and the detail lives in `fieldViolations`.
    public var message: String
    /// Every field-level violation found, in batch order — the `BadRequest.fieldViolations` detail.
    public var fieldViolations: [FieldViolation]

    public init(code: Int, status: String, message: String, fieldViolations: [FieldViolation]) {
        self.code = code
        self.status = status
        self.message = message
        self.fieldViolations = fieldViolations
    }

    /// Builds the `INVALID_ARGUMENT` (HTTP 400) failure Google returns when request validation fails.
    ///
    /// Expects a non-empty list; an empty one produces an error whose message claims 0 requests were
    /// invalid.
    public static func invalidArgument(_ violations: [FieldViolation]) -> BatchUpdateError {
        let summary = violations.count == 1
            ? violations[0].description
            : "\(violations.count) request(s) were invalid; nothing was applied."
        return BatchUpdateError(code: 400, status: "INVALID_ARGUMENT", message: summary,
                                fieldViolations: violations)
    }

    /// A request body that is not valid JSON, or not recognizable as a batch.
    ///
    /// HTTP 400 with no field violations: nothing parsed, so there is no field to point at.
    public static func invalidJSON(_ detail: String) -> BatchUpdateError {
        BatchUpdateError(code: 400, status: "INVALID_ARGUMENT",
                         message: "Request body is not a valid batchUpdate JSON: \(detail)",
                         fieldViolations: [])
    }

    /// The whole error rendered in Google's wire JSON, `{"error":{code,status,message,details:[…]}}`.
    ///
    /// Suitable for handing straight back to an agent to self-correct from. If serialization fails
    /// this returns a minimal object with the status and message only, never throwing.
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
