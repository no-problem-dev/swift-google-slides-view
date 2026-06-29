import Foundation
import GSlidesLayout
import GSlidesSchema

public enum GenerationContractError: Error, Hashable {
    case invalidJSON(String)
    case emptyPresentation
    case unknownLayout(String, allowed: [String])
}

/// スライド生成用の構造化出力コントラクト。バリデーションサンドイッチの受信側も担う。
/// プロバイダー側のスキーマ強制だけを信頼してはならない。
public enum GSlidesGenerationContract {
    /// モデルに提示するレイアウト語彙。プロファイルの定義済みレイアウトから
    /// UNSPECIFIED を除いたもの（モデルは常に選択するか省略する）。
    public static var allowedLayouts: [String] {
        PredefinedLayout.knownValues
            .filter { $0 != .unspecified }
            .map(\.rawValue)
    }

    /// SemanticPresentation の JSON Schema。単一の情報源: レイアウト enum は
    /// PredefinedLayout.knownValues から構成されるため、モデル型からズレることがない。
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
                                        "metrics": [
                                            "type": "array",
                                            "maxItems": 4,
                                            "description": "数値指標カード（実績の図解）。各 {label, value, unit?, ratio?}。ratio(0–1) があれば達成度バーを描く。テキストの羅列より数字を主役にしたい実績スライドで使う。",
                                            "items": [
                                                "type": "object",
                                                "properties": [
                                                    "label": ["type": "string", "maxLength": 24, "description": "指標名 e.g. 継続率"],
                                                    "value": ["type": "string", "maxLength": 12, "description": "値 e.g. 98（単位は unit へ）"],
                                                    "unit": ["type": "string", "maxLength": 8, "description": "単位 e.g. %, 社, 億円"],
                                                    "ratio": ["type": "number", "minimum": 0, "maximum": 1, "description": "0–1。割合/達成度ならバー表示"],
                                                ],
                                                "required": ["label", "value"],
                                                "additionalProperties": false,
                                            ],
                                        ],
                                        "chart": [
                                            "type": "object",
                                            "description": "単系列チャート（成長/推移の比較）。bars は時系列やカテゴリ。数字を並べるより推移を見せたいときに使う。",
                                            "properties": [
                                                "type": [
                                                    "type": "string",
                                                    "enum": ["bar", "line"],
                                                    "description": "bar=縦棒（比較）/ line=折れ線（推移）。省略時は bar。",
                                                ],
                                                "bars": [
                                                    "type": "array",
                                                    "minItems": 2,
                                                    "maxItems": 6,
                                                    "items": [
                                                        "type": "object",
                                                        "properties": [
                                                            "label": ["type": "string", "maxLength": 12, "description": "カテゴリ/期間 e.g. 2023"],
                                                            "value": ["type": "number", "description": "棒の高さの基準となる量（相対比較）"],
                                                            "caption": ["type": "string", "maxLength": 12, "description": "棒の上に出す表示値の上書き e.g. ¥1.2億"],
                                                        ],
                                                        "required": ["label", "value"],
                                                        "additionalProperties": false,
                                                    ],
                                                ],
                                            ],
                                            "required": ["bars"],
                                            "additionalProperties": false,
                                        ],
                                        "steps": [
                                            "type": "array",
                                            "minItems": 2,
                                            "maxItems": 5,
                                            "description": "左から右へのプロセス/手順フロー。各ステップは矢印で繋がるカードになる。手順や流れを見せたいときに使う。",
                                            "items": [
                                                "type": "object",
                                                "properties": [
                                                    "label": ["type": "string", "maxLength": 16, "description": "ステップ名 e.g. 調査"],
                                                    "caption": ["type": "string", "maxLength": 24, "description": "ステップの一言説明（任意）"],
                                                ],
                                                "required": ["label"],
                                                "additionalProperties": false,
                                            ],
                                        ],
                                        "quote": [
                                            "type": "object",
                                            "description": "顧客の声・推薦（社会的証明）。大きな引用として表示する。導入事例や信頼を示したいときに使う。",
                                            "properties": [
                                                "text": ["type": "string", "maxLength": 120, "description": "引用文（一文で印象的に）"],
                                                "author": ["type": "string", "maxLength": 24, "description": "発言者名（任意）"],
                                                "role": ["type": "string", "maxLength": 32, "description": "発言者の所属/役職（任意）"],
                                            ],
                                            "required": ["text"],
                                            "additionalProperties": false,
                                        ],
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

    /// バリデーションサンドイッチの受信側: 厳格なデコード + セマンティックチェック。
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

    /// 検証済みのエンドツーエンドパス: モデル出力バイト → プロファイルプレゼンテーション（`themeSpec` で焼き込み済み）。
    /// テーマはコンテンツから推論せず、個別に供給する（例: `GSlidesThemeContract` 経由。デフォルトはライト）。
    public static func presentation(from data: Data, themeSpec: ThemeSpec = .light) throws -> Presentation {
        PresentationExpander.expand(try validate(data), themeSpec: themeSpec)
    }
}
