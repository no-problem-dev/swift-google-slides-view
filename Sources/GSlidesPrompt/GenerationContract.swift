import Foundation
import GSlidesSchema

public enum GenerationContractError: Error, Hashable {
    case invalidJSON(String)
    case emptyDeck
    case unknownLayout(String, allowed: [String])
}

/// Structured-output contract for slide generation, plus the receiving side of
/// the validation sandwich: never trust provider-side schema enforcement alone.
public enum GSlidesGenerationContract {
    /// Layout vocabulary offered to the model — the profile's predefined layouts
    /// minus UNSPECIFIED (a model should always pick or omit).
    public static var allowedLayouts: [String] {
        PredefinedLayout.knownValues
            .filter { $0 != .unspecified }
            .map(\.rawValue)
    }

    /// JSON Schema for SemanticDeck, single source: the layout enum is composed
    /// from PredefinedLayout.knownValues so it can never drift from the model types.
    public static var jsonSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "maxLength": 100],
                "slides": [
                    "type": "array",
                    "minItems": 1,
                    "items": [
                        "type": "object",
                        "properties": [
                            "layout": [
                                "type": "string",
                                "enum": allowedLayouts,
                                "description": "Predefined layout. Omit to let the renderer infer it from content.",
                            ],
                            "title": ["type": "string", "maxLength": 80],
                            "big": [
                                "type": "boolean",
                                "description": "Emphasized title (a key message or a big number).",
                            ],
                            "subtitle": ["type": "string", "maxLength": 120],
                            "bodies": [
                                "type": "array",
                                "maxItems": 2,
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "text": ["type": "string"],
                                        "bullets": [
                                            "type": "array",
                                            "items": ["type": "string", "maxLength": 120],
                                            "maxItems": 8,
                                        ],
                                        "imageUrl": ["type": "string"],
                                    ],
                                    "additionalProperties": false,
                                ],
                            ],
                        ],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["title", "slides"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
    }

    /// Validation sandwich, receiving side: strict decode + semantic checks.
    public static func validate(_ data: Data) throws -> SemanticDeck {
        let deck: SemanticDeck
        do {
            deck = try JSONDecoder().decode(SemanticDeck.self, from: data)
        } catch {
            throw GenerationContractError.invalidJSON(String(describing: error))
        }
        guard !deck.slides.isEmpty else { throw GenerationContractError.emptyDeck }
        for slide in deck.slides {
            if let layout = slide.layout, !allowedLayouts.contains(layout) {
                throw GenerationContractError.unknownLayout(layout, allowed: allowedLayouts)
            }
        }
        return deck
    }

    /// Validated end-to-end path: model output bytes → profile presentation.
    public static func presentation(from data: Data) throws -> Presentation {
        DeckExpander.expand(try validate(data))
    }
}
