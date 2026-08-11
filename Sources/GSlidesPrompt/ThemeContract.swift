import Foundation
import GSlidesLayout
import GSlidesSchema

public enum GSlidesThemeContractError: Error, Equatable {
    case invalidJSON(String)
    /// A theme color type the pinned specification does not define — a typo such as "ACCENT7".
    case unknownTypes([String])
    /// Editable slots the model failed to supply. All 12 are required.
    case missingSlots([ThemeColorType])
    /// Slots whose RGB components fall outside the specified 0.0–1.0 range — usually 0–255 values.
    case outOfRange([ThemeColorType])
}

/// The structured-output contract for a deck's color intent, expressed in the Slides API's own shape.
///
/// Mirrors how `GSlidesEditContract` works: inject the exact authoritative schema into the system
/// prompt, then validate the model's output against it. There is no invented vocabulary and no
/// speculative "design brief" abstraction — the model emits a real `ColorScheme` of 12 editable
/// `ThemeColorType` slots with 0.0–1.0 float components, ready for the API as-is.
///
/// (catalog: theme-color-scheme-editable, rgb-color-range)
public enum GSlidesThemeContract {
    /// The 12 slots the model must supply, in discovery enum order.
    public static let editableSlots = ThemeColorType.editableSlots

    /// The JSON Schema for the tool argument: a `ColorScheme` restricted to the 12 editable types
    /// with 0.0–1.0 components.
    ///
    /// The "all 12, each exactly once" rule is stated here as a hint. JSON Schema can only express
    /// the count, not the uniqueness, so `validate(_:)` is what actually enforces it.
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

    /// A complete worked example in the exact wire shape.
    ///
    /// The package's default light palette, limited to the 12 editable slots so the model never
    /// learns to emit the four read-only aliases.
    public static func workedExample() -> String {
        let scheme = ColorScheme(colors: ThemeSpec.light.editableColors.map { ThemeColorPair(type: $0.0, color: $0.1) })
        let data = (try? JSONEncoder().encode(scheme)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return data
    }

    /// The system-instruction block to paste into a prompt: the rules, the schema and a worked example.
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

    /// Decodes a color scheme and enforces the authoritative rules: every type known, all 12 editable
    /// slots present, every component in 0.0–1.0.
    ///
    /// Non-editable slots the model may have included, such as TEXT1, are ignored rather than
    /// rejected — the same thing the API does with them.
    ///
    /// - Throws: ``GSlidesThemeContractError``, one failure at a time in that order, so a scheme with
    ///   two kinds of problem needs two round trips.
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

    /// The whole validated path: model output bytes to a `ThemeSpec` ready to bake into a master.
    ///
    /// - Throws: Whatever `validate(_:)` throws. The conversion itself cannot fail, since a validated
    ///   scheme always binds all 12 slots.
    public static func themeSpec(from data: Data) throws -> ThemeSpec {
        let scheme = try validate(data)
        guard let spec = ThemeSpec(colorScheme: scheme) else {
            // Unreachable: validate guarantees the 12 slots — but report rather than crash.
            throw GSlidesThemeContractError.missingSlots(scheme.missingEditableSlots)
        }
        return spec
    }

    /// The feedback to hand a model after a rejected theme: what to fix, in plain words it can act on.
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
