import Foundation
import GSlidesLayout
import GSlidesSchema

public enum GSlidesThemeContractError: Error, Equatable {
    case invalidJSON(String)
    /// スペックで定義されていないテーマカラータイプ（例: タイポ "ACCENT7"）。
    case unknownTypes([String])
    /// モデルが提供し損ねた（12 のうちの）編集可能スロット。
    case missingSlots([ThemeColorType])
    /// RGB コンポーネントが規定の 0.0–1.0 範囲外にあるスロット。
    case outOfRange([ThemeColorType])
}

/// プレゼンテーションのデザインインテント — **テーマカラースキーム** — に対する構造化出力コントラクト。
/// Slides API 自身のプロトコル形状で表現する。`GSlidesEditContract` のミラー: 正確な権威スキーマをシステムプロンプトに
/// 注入し、モデルの出力をそれに対して検証する。発明された語彙も推測的な "design brief" 抽象化もなく、
/// モデルは実際の `ColorScheme`（12 個の編集可能な `ThemeColorType` スロット、各 0.0–1.0 浮動小数 `RgbColor`）を
/// API がそのまま使用できる形式で出力する。
///
/// (catalog: theme-color-scheme-editable, rgb-color-range)
public enum GSlidesThemeContract {
    /// モデルが提供しなければならない 12 の編集可能スロット。discovery enum の順序で並ぶ。
    public static let editableSlots = ThemeColorType.editableSlots

    /// ツール引数の JSON Schema: `ColorScheme` `{ "colors": [ {type, color} … ] }`、
    /// 12 個の編集可能な `ThemeColorType` と 0.0–1.0 の `RgbColor` コンポーネントに制限する。
    /// "全 12、各 1 回" ルールはここで明示し、`validate` で厳密に強制する。
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

    /// 正確なワイヤー形状での完全なワーク済み例 — パッケージのデフォルトライトパレット、
    /// 12 の編集可能スロットに限定（モデルは 4 つの読み取り専用エイリアスを出力しない）。
    public static func workedExample() -> String {
        let scheme = ColorScheme(colors: ThemeSpec.light.editableColors.map { ThemeColorPair(type: $0.0, color: $0.1) })
        let data = (try? JSONEncoder().encode(scheme)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return data
    }

    /// システム指示ブロック: ルール（権威的な制約）+ スキーマ + ワーク済み例。
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

    /// バリデーションサンドイッチの受信側: `ColorScheme` をデコードし、権威的なルールを強制する —
    /// 全タイプが既知、12 の編集可能スロットが全て存在、全カラーが 0.0–1.0。モデルが含む可能性のある
    /// 非編集可能スロット（TEXT1 等）は API と同様に無視する。
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

    /// 検証済みのエンドツーエンド: モデル出力バイト → `ThemeSpec`（マスターへの焼き込み準備完了）。
    /// 検証済みスキームは常に 12 の編集可能スロットを全てバインドするため、変換は失敗しない。
    public static func themeSpec(from data: Data) throws -> ThemeSpec {
        let scheme = try validate(data)
        guard let spec = ThemeSpec(colorScheme: scheme) else {
            // Unreachable: validate guarantees the 12 slots — but report rather than crash.
            throw GSlidesThemeContractError.missingSlots(scheme.missingEditableSlots)
        }
        return spec
    }

    /// 拒否されたテーマに対する LLM 向けフィードバック: 自己修正できるよう、修正箇所を平易な言葉で示す。
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
