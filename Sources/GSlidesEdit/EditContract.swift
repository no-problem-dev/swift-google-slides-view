import Foundation
import GSlidesRequests
import GSlidesSchema

public enum GSlidesEditContractError: Error, Equatable {
    case invalidJSON(String)
    case emptyBatch
}

/// Contract for the edit loop. An editing agent refines a presentation by emitting **official batchUpdate
/// requests** — a curated subset of the same `Request` types the wire and the reducer already speak
/// — NOT an invented vocabulary. This keeps one source of truth (no parallel edit language to drift),
/// mirrors how real agent-editing systems work (Figma / Docs / Office emit concrete API ops), and
/// reuses the typed, tested request model. The schema + worked examples teach the shape.
///
/// `allowing:` restricts the offered operations to a subset (e.g. a user disabling "delete"): the
/// schema, examples, and validation all narrow to it, so the model is never shown a forbidden op.
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
                        + "Reference elements by the objectId from get_presentation. EMU units: 914400 = 1 inch. "
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

    /// System-instruction block: schema (what's allowed) + worked examples (the exact shape).
    public static func promptBlock(allowing allowed: Set<String>? = nil) -> String {
        let schema = (try? jsonSchemaData(allowing: allowed)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        ### EDIT SCHEMA:
        The `requests_json` argument MUST validate against this JSON Schema:
        \(schema)

        ### EDIT EXAMPLES (official batchUpdate shape — match this):
        \(examplesJSON(allowing: allowed))
        """
    }

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

    /// Validation sandwich, receiving side: strict decode of the official batch + non-empty check.
    /// Accepts `{"requests":[…]}` or a bare `[…]`. When `allowed` is set, requests using a
    /// non-permitted operation are dropped (the agent was only shown the permitted ones).
    public static func validate(_ data: Data, allowing allowed: Set<String>? = nil) throws -> [Request] {
        let decoded: [Request]
        do {
            if let batch = try? JSONDecoder().decode(BatchUpdatePresentationRequest.self, from: data),
               let r = batch.requests {
                decoded = r
            } else {
                decoded = try JSONDecoder().decode([Request].self, from: data)
            }
        } catch {
            throw GSlidesEditContractError.invalidJSON(String(describing: error))
        }
        guard !decoded.isEmpty else { throw GSlidesEditContractError.emptyBatch }
        guard let allowed else { return decoded }
        return decoded.filter { operationName(of: $0).map(allowed.contains) ?? false }
    }

    /// Validated end-to-end path: model output bytes → official requests → updated presentation.
    /// Best-effort: a single bad request (stale objectId, unsupported op) is skipped, not fatal.
    public static func apply(_ data: Data, to presentation: Presentation, allowing allowed: Set<String>? = nil) throws -> Presentation {
        presentation.applyingLenient(try validate(data, allowing: allowed)).presentation
    }
}
