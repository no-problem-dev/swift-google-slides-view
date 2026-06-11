import Foundation
import GSlidesRequests
import GSlidesSchema

/// Contract for the edit loop. An editing agent refines a presentation by emitting **official batchUpdate
/// requests** — a curated subset of the same `Request` types the wire and the reducer already speak
/// — NOT an invented vocabulary. This keeps one source of truth (no parallel edit language to drift),
/// mirrors how real agent-editing systems work (Figma / Docs / Office emit concrete API ops), and
/// reuses the typed, tested request model. The schema + worked examples teach the shape.
///
/// The flow is **decode → preflight → atomic apply**, faithful to the real API: the whole batch is
/// validated up front (`PreflightValidator`) and, if anything is wrong, NOTHING is applied and a
/// `BatchUpdateError` carrying every `FieldViolation` is thrown — the agent fixes them all in one
/// pass (`promptFeedback`) instead of one server round-trip at a time.
///
/// `allowing:` restricts the offered operations to a subset (e.g. a user disabling "delete"): the
/// schema, examples, and prompt all narrow to it, and a request using a forbidden op is reported as
/// an `OPERATION_NOT_PERMITTED` violation.
public enum GSlidesEditContract {
    /// The curated subset of the 44 batchUpdate operations offered for editing — the ones that adjust
    /// an existing presentation. Deliberately small (oversized operation sets collapse selection accuracy).
    public static let curatedOperations = [
        "updatePageElementTransform",   // move / resize an element
        "updateTextStyle",              // bold / italic / color / size of text
        "updateShapeProperties",        // fill / outline of a shape
        "replaceAllText",               // find & replace text across the presentation
        "insertText",                   // insert text into an element
        "deleteText",                   // delete a text range
        "deleteObject",                 // remove an element (or slide)
        "duplicateObject",              // copy an element
        "updatePageElementsZOrder",     // bring to front / send to back
    ]

    /// One worked example per curated operation, in the exact official wire shape — the teaching
    /// material the agent matches (also lets `allowing:` show only the permitted shapes).
    public static let operationExamples: [String: String] = [
        "updatePageElementTransform": #"{"updatePageElementTransform":{"objectId":"<id>","applyMode":"RELATIVE","transform":{"scaleX":1,"scaleY":1,"translateX":457200,"translateY":-228600,"unit":"EMU"}}}"#,
        "updateTextStyle": #"{"updateTextStyle":{"objectId":"<id>","style":{"bold":true,"foregroundColor":{"opaqueColor":{"rgbColor":{"red":0.86,"green":0.15,"blue":0.15}}}},"fields":"bold,foregroundColor","textRange":{"type":"ALL"}}}"#,
        "updateShapeProperties": #"{"updateShapeProperties":{"objectId":"<id>","shapeProperties":{"shapeBackgroundFill":{"solidFill":{"color":{"rgbColor":{"red":0.10,"green":0.11,"blue":0.13}}}}},"fields":"shapeBackgroundFill.solidFill.color"}}"#,
        "replaceAllText": #"{"replaceAllText":{"containsText":{"text":"Old title","matchCase":false},"replaceText":"New title"}}"#,
        "insertText": #"{"insertText":{"objectId":"<id>","text":"New text","insertionIndex":0}}"#,
        "deleteText": #"{"deleteText":{"objectId":"<id>","textRange":{"type":"ALL"}}}"#,
        "deleteObject": #"{"deleteObject":{"objectId":"<id>"}}"#,
        "duplicateObject": #"{"duplicateObject":{"objectId":"<id>"}}"#,
        "updatePageElementsZOrder": #"{"updatePageElementsZOrder":{"pageElementObjectIds":["<id>"],"operation":"BRING_TO_FRONT"}}"#,
    ]

    /// The curated operations actually offered, narrowed by `allowed` (nil = all), order preserved.
    public static func offeredOperations(allowing allowed: Set<String>? = nil) -> [String] {
        curatedOperations.filter { allowed?.contains($0) ?? true }
    }

    // MARK: - Decode → preflight → atomic apply

    /// Structural decode of the official batch + non-empty check. Accepts `{"requests":[…]}` or a
    /// bare `[…]`. Throws `BatchUpdateError` (HTTP 400) on malformed JSON or an empty batch — the
    /// same shape the real API returns, so a host can relay it to the agent unchanged.
    public static func decode(_ data: Data) throws -> [Request] {
        let decoded: [Request]
        do {
            if let batch = try? JSONDecoder().decode(BatchUpdatePresentationRequest.self, from: data),
               let r = batch.requests {
                decoded = r
            } else {
                decoded = try JSONDecoder().decode([Request].self, from: data)
            }
        } catch {
            throw BatchUpdateError.invalidJSON(String(describing: error))
        }
        guard !decoded.isEmpty else {
            throw BatchUpdateError.invalidArgument([FieldViolation(
                field: "requests", description: "The batch must contain at least one request.",
                reason: .requiredFieldMissing)])
        }
        return decoded
    }

    /// Decode + full preflight against `presentation`. Returns the validated requests if the batch
    /// is safe to apply, or throws `BatchUpdateError` listing **every** violation (nothing applied).
    @discardableResult
    public static func validate(
        _ data: Data, against presentation: Presentation,
        allowing allowed: Set<String>? = nil, policy: PreflightValidator.Policy = .default
    ) throws -> [Request] {
        let requests = try decode(data)
        let violations = PreflightValidator.violations(
            in: requests, against: presentation, allowing: allowed, policy: policy)
        if !violations.isEmpty { throw BatchUpdateError.invalidArgument(violations) }
        return requests
    }

    /// Validated end-to-end path: model output bytes → official requests → updated presentation.
    /// **Atomic**: if preflight finds any violation the whole batch is rejected and `presentation`
    /// is returned unchanged via the thrown error — nothing is partially applied (catalog:
    /// batch-atomicity).
    public static func apply(
        _ data: Data, to presentation: Presentation,
        allowing allowed: Set<String>? = nil, policy: PreflightValidator.Policy = .default
    ) throws -> Presentation {
        let requests = try validate(data, against: presentation, allowing: allowed, policy: policy)
        return try presentation.applying(requests)
    }

    /// LLM-facing feedback for a rejected batch: the API-shaped error JSON plus a short instruction
    /// to fix every listed violation and resend. Hand this back to the agent to drive self-correction.
    public static func promptFeedback(for error: BatchUpdateError) -> String {
        """
        ### EDIT REJECTED (nothing was applied — the batch is atomic):
        \(error.wireJSON())

        Fix EVERY fieldViolation above (each `field` is a path into your requests array) and resend
        the corrected batch. Do not resend the un-fixed requests.
        """
    }

    // MARK: - Request introspection

    /// The wire operation name of a request (its single set member), or nil if none — public so a
    /// host can label or filter requests by operation.
    public static func operationName(of request: Request) -> String? {
        for child in Mirror(reflecting: request).children {
            if let name = child.label, Mirror(reflecting: child.value).children.first != nil {
                return name
            }
        }
        return nil
    }

    // MARK: - LLM teaching material (schema + examples + constraints)

    /// JSON Schema for the tool argument: `{ "requests": [ <one curated batchUpdate request> … ] }`.
    /// The item shape is intentionally permissive (one key per request, mirroring the wire union);
    /// the operation list + worked EXAMPLES carry the precise shape.
    public static func jsonSchema(allowing allowed: Set<String>? = nil) -> [String: Any] {
        let ops = offeredOperations(allowing: allowed)
        return [
            "type": "object",
            "properties": [
                "requests": [
                    "type": "array",
                    "minItems": 1,
                    "description":
                        "Edits to apply IN ORDER, each an official Google Slides batchUpdate request "
                        + "(exactly one of: \(ops.joined(separator: ", "))). "
                        + "Reference elements by the objectId from inspect_presentation. EMU units: 914400 = 1 inch. "
                        + "Colors are rgbColor with red/green/blue in 0..1. For update* requests you may "
                        + "omit `fields` to update exactly the attributes you set. See the EXAMPLES.",
                    "items": ["type": "object"],
                ],
            ],
            "required": ["requests"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData(allowing allowed: Set<String>? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema(allowing: allowed), options: [.sortedKeys])
    }

    /// Worked examples (only the offered operations) wrapped in the `{"requests":[…]}` envelope.
    public static func examplesJSON(allowing allowed: Set<String>? = nil) -> String {
        let items = offeredOperations(allowing: allowed)
            .compactMap { operationExamples[$0] }
            .joined(separator: ",\n  ")
        return "{\"requests\":[\n  \(items)\n]}"
    }

    /// The hard constraints the validator enforces, stated for the agent so it gets edits right the
    /// first time instead of learning them from rejections. Grounded in `constraints-catalog.yaml`.
    public static let constraintRules = """
    ### EDIT RULES (enforced — a violation rejects the WHOLE batch, applying nothing):
    - Reference only objectIds that exist in the current presentation (from inspect_presentation).
    - Each request sets exactly ONE operation.
    - Coordinates are EMU (914400 = 1 inch; 12700 = 1 point); translateX/Y is the element's
      UPPER-LEFT corner. Keep elements on the slide — do not move them entirely off-page.
    - Do not use scaleX/scaleY of 0 (it makes the element vanish).
    - Enum fields accept only their documented values; rgbColor components are 0..1.
    - In `fields`, list exactly the attributes you set; use "*" alone (never mixed with paths).
    """

    /// System-instruction block: rules (what's enforced) + schema (what's allowed) + worked examples.
    public static func promptBlock(allowing allowed: Set<String>? = nil) -> String {
        let schema = (try? jsonSchemaData(allowing: allowed)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        \(constraintRules)

        ### EDIT SCHEMA:
        The `requests_json` argument MUST validate against this JSON Schema:
        \(schema)

        ### EDIT EXAMPLES (official batchUpdate shape — match this):
        \(examplesJSON(allowing: allowed))
        """
    }
}
