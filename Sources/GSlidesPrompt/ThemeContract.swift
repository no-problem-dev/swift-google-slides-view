import Foundation
import GSlidesLayout
import GSlidesSchema

public enum GSlidesThemeContractError: Error, Equatable {
    case invalidJSON(String)
    /// Theme color types that aren't defined by the spec (e.g. a typo'd "ACCENT7").
    case unknownTypes([String])
    /// Editable slots (of the 12) the model failed to provide.
    case missingSlots([ThemeColorType])
    /// Slots whose RGB components fall outside the documented 0.0–1.0 range.
    case outOfRange([ThemeColorType])
}

/// Structured-output contract for a presentation's design intent — its **theme color scheme** — in
/// the Slides API's own protocol shape. Mirrors `GSlidesEditContract`: inject the exact authoritative
/// schema into the system prompt and validate the model's output against it. No invented vocabulary,
/// no speculative "design brief" abstraction — the model emits a real `ColorScheme` (the 12 editable
/// `ThemeColorType` slots, each an `RgbColor` of 0.0–1.0 floats), exactly as the API consumes it.
///
/// (catalog: theme-color-scheme-editable, rgb-color-range)
public enum GSlidesThemeContract {
    /// The 12 editable slots the model must provide, in discovery enum order.
    public static let editableSlots = ThemeColorType.editableSlots

    /// JSON Schema for the tool argument: a `ColorScheme` `{ "colors": [ {type, color} … ] }`,
    /// restricted to the 12 editable `ThemeColorType`s with `RgbColor` components in 0.0–1.0. The
    /// "all 12, each once" rule is stated here and enforced precisely in `validate`.
    public static var jsonSchema: [String: Any] {
        let rgb: [String: Any] = [
            "type": "object",
            "description": "An RGB color; each component is a float from 0.0 to 1.0 (NOT 0–255).",
            "properties": [
                "red": ["type": "number", "minimum": 0, "maximum": 1],
                "green": ["type": "number", "minimum": 0, "maximum": 1],
                "blue": ["type": "number", "minimum": 0, "maximum": 1],
            ],
            "required": ["red", "green", "blue"],
            "additionalProperties": false,
        ]
        return [
            "type": "object",
            "properties": [
                "colors": [
                    "type": "array",
                    "description":
                        "The theme color scheme: provide ALL 12 editable ThemeColorTypes "
                        + "(\(editableSlots.map(\.rawValue).joined(separator: ", "))), each exactly once. "
                        + "These bake into the master ColorScheme; elements reference them symbolically "
                        + "(e.g. ACCENT1), so the whole deck recolors to this palette.",
                    "minItems": 12,
                    "maxItems": 12,
                    "items": [
                        "type": "object",
                        "properties": [
                            "type": ["type": "string", "enum": editableSlots.map(\.rawValue)],
                            "color": rgb,
                        ],
                        "required": ["type", "color"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["colors"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
    }

    /// A complete worked example in the exact wire shape — the package's default light palette,
    /// limited to the 12 editable slots (the model never emits the four read-only aliases).
    public static func workedExample() -> String {
        let scheme = ColorScheme(colors: ThemeSpec.light.editableColors.map { ThemeColorPair(type: $0.0, color: $0.1) })
        let data = (try? JSONEncoder().encode(scheme)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return data
    }

    /// System-instruction block: rules (the authoritative constraints) + schema + a worked example.
    public static func promptBlock() -> String {
        let schema = (try? jsonSchemaData()).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        ### THEME RULES (the design intent — a Google Slides color scheme):
        - Provide ALL 12 editable theme colors, each exactly once: \(editableSlots.map(\.rawValue).joined(separator: ", ")).
        - Each color is an RgbColor with red/green/blue as floats from 0.0 to 1.0 (a hex like #1A73E8 is r=26/255, g=115/255, b=232/255).
        - DARK1 = primary text, LIGHT1 = canvas/background, DARK2 = muted text, LIGHT2 = subtle surface,
          ACCENT1–6 = accents (ACCENT1 is the primary brand color), HYPERLINK/FOLLOWED_HYPERLINK = links.
        - Express the requested look (e.g. "white-based, refined, blue accent") by choosing these concrete colors.

        ### THEME SCHEMA:
        The argument MUST validate against this JSON Schema:
        \(schema)

        ### THEME EXAMPLE (exact shape — match this):
        \(workedExample())
        """
    }

    /// Validation sandwich, receiving side: decode the `ColorScheme`, then enforce the authoritative
    /// rules — every type known, all 12 editable slots present, every color in 0.0–1.0. Non-editable
    /// slots the model may include (TEXT1 etc.) are ignored, exactly as the API ignores them.
    public static func validate(_ data: Data) throws -> ColorScheme {
        let scheme: ColorScheme
        do {
            scheme = try JSONDecoder().decode(ColorScheme.self, from: data)
        } catch {
            throw GSlidesThemeContractError.invalidJSON(String(describing: error))
        }
        let unknown = (scheme.colors ?? []).compactMap(\.type).filter { !$0.isKnown }
        if !unknown.isEmpty { throw GSlidesThemeContractError.unknownTypes(unknown.map(\.rawValue)) }
        if !scheme.missingEditableSlots.isEmpty { throw GSlidesThemeContractError.missingSlots(scheme.missingEditableSlots) }
        if !scheme.outOfRangeSlots.isEmpty { throw GSlidesThemeContractError.outOfRange(scheme.outOfRangeSlots) }
        return scheme
    }

    /// Validated end-to-end: model output bytes → `ThemeSpec` (ready to bake into a master). The
    /// validated scheme always binds all 12 editable slots, so the conversion never fails.
    public static func themeSpec(from data: Data) throws -> ThemeSpec {
        let scheme = try validate(data)
        guard let spec = ThemeSpec(colorScheme: scheme) else {
            // Unreachable: validate guarantees the 12 slots — but report rather than crash.
            throw GSlidesThemeContractError.missingSlots(scheme.missingEditableSlots)
        }
        return spec
    }

    /// LLM-facing feedback for a rejected theme: what to fix, in plain terms, so it can self-correct.
    public static func feedback(for error: GSlidesThemeContractError) -> String {
        switch error {
        case .invalidJSON(let detail):
            return "The theme was not valid JSON: \(detail). Re-emit a {\"colors\":[…]} object."
        case .unknownTypes(let types):
            return "Unknown theme color type(s): \(types.joined(separator: ", ")). Use only: "
                + editableSlots.map(\.rawValue).joined(separator: ", ") + "."
        case .missingSlots(let slots):
            return "Missing required theme color(s): \(slots.map(\.rawValue).joined(separator: ", ")). "
                + "Provide all 12 editable slots, each exactly once."
        case .outOfRange(let slots):
            return "Color component(s) out of range for: \(slots.map(\.rawValue).joined(separator: ", ")). "
                + "red/green/blue must each be between 0.0 and 1.0."
        }
    }
}
