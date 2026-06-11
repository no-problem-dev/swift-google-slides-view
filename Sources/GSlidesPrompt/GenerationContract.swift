import Foundation
import GSlidesLayout
import GSlidesSchema

public enum GenerationContractError: Error, Hashable {
    case invalidJSON(String)
    case emptyPresentation
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

    /// JSON Schema for SemanticPresentation, single source: the layout enum is composed
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
                                // All text supports inline emphasis: **bold** and ==accent== (brand-colored).
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "text": ["type": "string", "description": "Body text. Inline emphasis: **bold**, ==accent==."],
                                        "bullets": [
                                            "type": "array",
                                            "maxItems": 8,
                                            "description": "Bullet lines. A string is a top-level bullet; use {text, level} to nest (level 0–2).",
                                            "items": [
                                                "oneOf": [
                                                    ["type": "string", "maxLength": 120],
                                                    [
                                                        "type": "object",
                                                        "properties": [
                                                            "text": ["type": "string", "maxLength": 120],
                                                            "level": ["type": "integer", "minimum": 0, "maximum": 2],
                                                        ],
                                                        "required": ["text"],
                                                        "additionalProperties": false,
                                                    ],
                                                ],
                                            ],
                                        ],
                                        "imageUrl": ["type": "string"],
                                        "table": [
                                            "type": "object",
                                            "description": "A simple table: optional header row + rows of cell strings.",
                                            "properties": [
                                                "headers": ["type": "array", "items": ["type": "string"]],
                                                "rows": [
                                                    "type": "array",
                                                    "items": ["type": "array", "items": ["type": "string"]],
                                                ],
                                            ],
                                            "required": ["rows"],
                                            "additionalProperties": false,
                                        ],
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
    public static func validate(_ data: Data) throws -> SemanticPresentation {
        let presentation: SemanticPresentation
        do {
            presentation = try JSONDecoder().decode(SemanticPresentation.self, from: data)
        } catch {
            throw GenerationContractError.invalidJSON(String(describing: error))
        }
        guard !presentation.slides.isEmpty else { throw GenerationContractError.emptyPresentation }
        for slide in presentation.slides {
            if let layout = slide.layout, !allowedLayouts.contains(layout) {
                throw GenerationContractError.unknownLayout(layout, allowed: allowedLayouts)
            }
        }
        return presentation
    }

    /// Validated end-to-end path: model output bytes → profile presentation, baked with `themeSpec`
    /// (the design intent — default light). Theme is supplied separately (e.g. by
    /// `GSlidesThemeContract`), never inferred from the content.
    public static func presentation(from data: Data, themeSpec: ThemeSpec = .light) throws -> Presentation {
        PresentationExpander.expand(try validate(data), themeSpec: themeSpec)
    }
}
