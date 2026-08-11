import Foundation
import GSlidesRequests
import GSlidesSchema

/// The contract an editing agent works against: it emits official batchUpdate requests, not a
/// private edit vocabulary.
///
/// Requests are a curated subset of the same `Request` type the wire and the reducer already use, so
/// there is no second edit language to keep in sync. The schema plus worked examples teach the shape.
///
/// The flow is decode → preflight → atomic apply, faithful to the real API: the whole batch is
/// validated up front by `PreflightValidator`, and on any problem nothing is applied and a
/// `BatchUpdateError` carrying every `FieldViolation` is thrown. Feed that to `promptFeedback(for:)`
/// and the agent fixes everything in one pass instead of one server round trip per mistake.
///
/// Pass `allowing:` to narrow the offered operations — to withhold deletion, say. It narrows the
/// schema, the examples and the prompt together, and a request using a withheld operation is
/// reported as an `OPERATION_NOT_PERMITTED` violation rather than being ignored.
public enum GSlidesEditContract {
    /// The subset of the API's 44 batchUpdate operations offered for editing an existing deck.
    ///
    /// Deliberately small: selection accuracy drops as the operation set grows. Ordering is the
    /// order they are presented to the model.
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

    /// One worked example per curated operation, in the exact official wire shape, keyed by
    /// operation name.
    ///
    /// Teaching material for the agent to pattern-match against. Filter with `allowing:` so only the
    /// permitted shapes are ever shown.
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

    /// The curated operations actually offered, in curated order.
    ///
    /// - Parameter allowed: The names to keep; nil offers all of them. Names that are not curated
    ///   operations are ignored rather than added.
    public static func offeredOperations(allowing allowed: Set<String>? = nil) -> [String] {
        curatedOperations.filter { allowed?.contains($0) ?? true }
    }

    // MARK: - Decode → preflight → atomic apply

    /// Decodes an official batch, accepting either `{"requests":[…]}` or a bare `[…]`.
    ///
    /// Structural only — it checks that the batch parses and is non-empty, not that the requests can
    /// be applied. Run `validate(_:against:allowing:policy:)` for that.
    ///
    /// - Throws: `BatchUpdateError` with HTTP 400 for unparseable JSON or an empty batch. The shape
    ///   matches what the real API returns, so a host can relay it to the agent unchanged.
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

    /// Decodes and fully preflights a batch against a presentation, returning the requests when it is
    /// safe to apply.
    ///
    /// - Throws: `BatchUpdateError` listing **every** violation found, not just the first. The
    ///   presentation is untouched either way — this only reads it.
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

    /// The whole validated path: model output bytes → official requests → updated presentation.
    ///
    /// Atomic. If preflight finds any violation the entire batch is rejected and `presentation` is
    /// left as it was — nothing is partially applied (catalog: batch-atomicity).
    ///
    /// - Throws: `BatchUpdateError` from decoding, preflight, or the reducer's own safety net.
    public static func apply(
        _ data: Data, to presentation: Presentation,
        allowing allowed: Set<String>? = nil, policy: PreflightValidator.Policy = .default
    ) throws -> Presentation {
        let requests = try validate(data, against: presentation, allowing: allowed, policy: policy)
        return try presentation.applying(requests)
    }

    /// The feedback to hand an agent after a rejected batch: the API-shaped error JSON plus an
    /// instruction to fix every listed violation and resend.
    public static func promptFeedback(for error: BatchUpdateError) -> String {
        """
        ### EDIT REJECTED (nothing was applied — the batch is atomic):
        \(error.wireJSON())

        Fix EVERY fieldViolation above (each `field` is a path into your requests array) and resend
        the corrected batch. Do not resend the un-fixed requests.
        """
    }

    // MARK: - Request introspection

    /// The request's wire operation name — its single set member — or nil when none is set.
    ///
    /// Public so a host can label or filter requests by operation, for logging or an approval gate.
    /// If more than one member is set this returns the first, so use it for display rather than
    /// validation.
    public static func operationName(of request: Request) -> String? {
        for child in Mirror(reflecting: request).children {
            if let name = child.label, Mirror(reflecting: child.value).children.first != nil {
                return name
            }
        }
        return nil
    }

    // MARK: - LLM teaching material (schema + examples + constraints)

    /// The JSON Schema for the tool argument: `{ "requests": [ <one curated batchUpdate request> … ] }`.
    ///
    /// The item shape is deliberately permissive — one key per request, mirroring the wire union —
    /// because JSON Schema cannot express a 44-way union readably. The operation list and the worked
    /// examples carry the precise shape, and preflight catches what the schema lets through.
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

    /// The worked examples for the offered operations, wrapped in a `{"requests":[…]}` envelope.
    public static func examplesJSON(allowing allowed: Set<String>? = nil) -> String {
        let items = offeredOperations(allowing: allowed)
            .compactMap { operationExamples[$0] }
            .joined(separator: ",\n  ")
        return "{\"requests\":[\n  \(items)\n]}"
    }

    /// The hard constraints the validator enforces, stated up front so an agent gets them right the
    /// first time instead of learning from rejections. Sourced from `constraints-catalog.yaml`.
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

    /// The system-instruction block to paste into a prompt: the rules, the schema and the worked
    /// examples, all narrowed by `allowing:` together.
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
