import Foundation
import GSlidesRequests
import GSlidesSchema

public enum GSlidesEditContractError: Error, Equatable {
    case invalidJSON(String)
    case emptyBatch
}

/// Contract for the edit loop. An editing agent refines a deck by emitting **official batchUpdate
/// requests** — a curated subset of the same `Request` types the wire and the reducer already speak
/// — NOT an invented vocabulary. This keeps one source of truth (no parallel edit language to drift),
/// mirrors how real agent-editing systems work (Figma / Docs / Office emit concrete API ops), and
/// reuses the typed, tested request model. The schema + worked examples teach the shape; the model
/// only needs the curated ~9 operations, kept small so tool selection stays sharp.
public enum GSlidesEditContract {
    /// The curated subset of the 44 batchUpdate operations offered for editing — the ones that adjust
    /// an existing deck. Deliberately small (oversized tool/operation sets collapse selection accuracy).
    public static let curatedOperations = [
        "updatePageElementTransform",   // move / resize an element
        "updateTextStyle",              // bold / italic / color / size of text
        "updateShapeProperties",        // fill / outline of a shape
        "replaceAllText",               // find & replace text across the deck
        "insertText",                   // insert text into an element
        "deleteText",                   // delete a text range
        "deleteObject",                 // remove an element (or slide)
        "duplicateObject",              // copy an element
        "updatePageElementsZOrder",     // bring to front / send to back
    ]

    /// JSON Schema for the tool argument: `{ "requests": [ <one curated batchUpdate request> … ] }`.
    /// The item shape is intentionally permissive (one key per request, mirroring the wire union);
    /// the curated operation list + the worked EXAMPLES carry the precise shape (the proven way to
    /// keep an agent on the official format without enumerating every nested field).
    public static var jsonSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "requests": [
                    "type": "array",
                    "minItems": 1,
                    "description":
                        "Edits to apply IN ORDER, each an official Google Slides batchUpdate request "
                        + "(exactly one of: \(curatedOperations.joined(separator: ", "))). "
                        + "Reference elements by the objectId from inspect_deck. EMU units: 914400 = 1 inch. "
                        + "Colors are rgbColor with red/green/blue in 0..1. For update* requests you may "
                        + "omit `fields` to update exactly the attributes you set. See the EXAMPLES.",
                    "items": ["type": "object"],
                ],
            ],
            "required": ["requests"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
    }

    /// Worked examples in the exact official wire shape — the teaching material an agent matches.
    public static func examplesJSON() -> String {
        """
        {"requests":[
          {"updatePageElementTransform":{"objectId":"<id>","applyMode":"RELATIVE","transform":{"scaleX":1,"scaleY":1,"translateX":457200,"translateY":-228600,"unit":"EMU"}}},
          {"updateTextStyle":{"objectId":"<id>","style":{"bold":true,"foregroundColor":{"opaqueColor":{"rgbColor":{"red":0.86,"green":0.15,"blue":0.15}}}},"fields":"bold,foregroundColor","textRange":{"type":"ALL"}}},
          {"updateShapeProperties":{"objectId":"<id>","shapeProperties":{"shapeBackgroundFill":{"solidFill":{"color":{"rgbColor":{"red":0.10,"green":0.11,"blue":0.13}}}}},"fields":"shapeBackgroundFill.solidFill.color"}},
          {"replaceAllText":{"containsText":{"text":"Old title","matchCase":false},"replaceText":"New title"}},
          {"deleteObject":{"objectId":"<id>"}},
          {"duplicateObject":{"objectId":"<id>"}},
          {"updatePageElementsZOrder":{"pageElementObjectIds":["<id>"],"operation":"BRING_TO_FRONT"}}
        ]}
        """
    }

    /// System-instruction block: schema (what's allowed) + worked examples (the exact shape).
    public static func promptBlock() -> String {
        let schema = (try? jsonSchemaData()).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        ### EDIT SCHEMA:
        The `requests_json` argument MUST validate against this JSON Schema:
        \(schema)

        ### EDIT EXAMPLES (official batchUpdate shape — match this):
        \(examplesJSON())
        """
    }

    /// Validation sandwich, receiving side: strict decode of the official batch + non-empty check.
    /// Accepts either `{"requests":[…]}` or a bare `[…]` array.
    public static func validate(_ data: Data) throws -> [Request] {
        let requests: [Request]
        do {
            if let batch = try? JSONDecoder().decode(BatchUpdatePresentationRequest.self, from: data),
               let r = batch.requests {
                requests = r
            } else {
                requests = try JSONDecoder().decode([Request].self, from: data)
            }
        } catch {
            throw GSlidesEditContractError.invalidJSON(String(describing: error))
        }
        guard !requests.isEmpty else { throw GSlidesEditContractError.emptyBatch }
        return requests
    }

    /// Validated end-to-end path: model output bytes → official requests → updated presentation.
    /// Best-effort: a single bad request (stale objectId, unsupported op) is skipped, not fatal.
    public static func apply(_ data: Data, to presentation: Presentation) throws -> Presentation {
        presentation.applyingLenient(try validate(data)).presentation
    }
}
