import Foundation
import GSlidesSchema

public enum GSlidesEditContractError: Error, Equatable {
    case invalidJSON(String)
    case emptyBatch
    case unknownOp(String)
}

/// Structured-output contract for the edit loop — the compact tool schema an agent fills to refine
/// a deck, plus the receiving validation. Deliberately small (a handful of intent ops keyed by stable
/// `objectId`), so the model spends tokens on *what to change*, not on relearning the wire format.
public enum GSlidesEditContract {
    public static var jsonSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "edits": [
                    "type": "array",
                    "minItems": 1,
                    "description": "Edits to apply, in order. Reference elements by their objectId.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "op": [
                                "type": "string",
                                "enum": ["move", "setText", "restyle", "delete", "duplicate", "order"],
                            ],
                            "id": ["type": "string", "description": "Target element's objectId."],
                            "dxEmu": ["type": "number", "description": "move: horizontal nudge in EMU (914400 = 1 inch)."],
                            "dyEmu": ["type": "number", "description": "move: vertical nudge in EMU."],
                            "text": ["type": "string", "description": "setText: the element's new text."],
                            "bold": ["type": "boolean"],
                            "italic": ["type": "boolean"],
                            "underline": ["type": "boolean"],
                            "colorHex": ["type": "string", "description": "restyle: text color as #RRGGBB."],
                            "fontSizePt": ["type": "number", "description": "restyle: font size in points."],
                            "newId": ["type": "string", "description": "duplicate: objectId for the copy."],
                            "order": ["type": "string", "enum": ["front", "back", "forward", "backward"]],
                        ],
                        "required": ["op", "id"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["edits"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
    }

    /// Validation sandwich, receiving side: strict decode + non-empty check.
    public static func validate(_ data: Data) throws -> SemanticEditBatch {
        let batch: SemanticEditBatch
        do {
            batch = try JSONDecoder().decode(SemanticEditBatch.self, from: data)
        } catch {
            throw GSlidesEditContractError.invalidJSON(String(describing: error))
        }
        guard !batch.edits.isEmpty else { throw GSlidesEditContractError.emptyBatch }
        return batch
    }

    /// Validated end-to-end path: model output bytes → edits → updated presentation.
    public static func apply(_ data: Data, to presentation: Presentation) throws -> Presentation {
        try presentation.applying(validate(data))
    }
}
