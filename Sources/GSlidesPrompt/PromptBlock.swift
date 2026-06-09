import Foundation

/// Few-shot examples built **from the Swift type system** instead of hand-written JSON — the
/// slide-deck counterpart of `A2UIExample`. A hand-authored string drifts and silently goes
/// invalid (wrong layout name, a field the schema dropped); constructing the example from typed
/// `SemanticDeck` values and serializing guarantees it stays structurally valid, and a test pins it.
extension GSlidesGenerationContract {

    /// The canonical example AND the quality bar. The model is told to MATCH this deck's variety,
    /// density and layout usage rather than read prose rules — teaching by demonstration. Built
    /// from typed values; localized (the host's role prompt sets the language, the content shows it).
    public static func exampleDeck() -> SemanticDeck {
        SemanticDeck(title: "リモートワーク時代の生産性", slides: [
            SemanticSlide(
                layout: "TITLE",
                title: "リモートワーク時代の生産性",
                subtitle: "場所に縛られない働き方が、成果をどう変えるか"
            ),
            SemanticSlide(layout: "SECTION_HEADER", title: "なぜ今、働き方なのか"),
            SemanticSlide(layout: "TITLE_AND_BODY", title: "変化を後押しする3つの力", bodies: [
                SemanticBody(bullets: [
                    "**技術**：高速回線とクラウドでどこでも仕事ができる",
                    "**人材**：優秀な人ほど柔軟な働き方を選ぶ",
                    "**コスト**：オフィス縮小で固定費を==大きく削減==",
                ]),
            ]),
            SemanticSlide(layout: "BIG_NUMBER", title: "77%", big: true, bodies: [
                SemanticBody(text: "の働き手が、週1回以上の在宅勤務を希望している"),
            ]),
            SemanticSlide(layout: "TITLE_AND_TWO_COLUMNS", title: "オフィス と リモート", bodies: [
                SemanticBody(bullets: [
                    "偶発的な雑談から生まれる発想",
                    "新人の立ち上がりが速い",
                    "通勤と固定時間に縛られる",
                ]),
                SemanticBody(bullets: [
                    "深い集中時間を確保しやすい",
                    "居住地に縛られず採用できる",
                    "意図的な情報共有が必要になる",
                ]),
            ]),
            SemanticSlide(layout: "TITLE_AND_BODY", title: "生産性を高める3つの習慣", bodies: [
                SemanticBody(bullets: [
                    "非同期コミュニケーション",
                    SemanticBullet("文章で決定を残し、後から追えるようにする", level: 1),
                    SemanticBullet("会議は意思決定が必要なときだけに絞る", level: 1),
                    "集中と休息の境界",
                    SemanticBullet("始業と終業に小さな儀式を設けて切り替える", level: 1),
                    "進捗の可視化",
                    SemanticBullet("オープンに共有して信頼を担保する", level: 1),
                ]),
            ]),
            SemanticSlide(layout: "BIG_NUMBER", title: "2.5倍", big: true, bodies: [
                SemanticBody(text: "集中できた時間の差が、成果の差として表れる"),
            ]),
            SemanticSlide(layout: "TITLE_AND_BODY", title: "働き方モデルの比較", bodies: [
                SemanticBody(table: SemanticTable(
                    headers: ["項目", "オフィス中心", "リモート中心"],
                    rows: [
                        ["深い集中時間", "確保しにくい", "確保しやすい"],
                        ["偶発的な対話", "多い", "少ない"],
                        ["採用できる範囲", "通勤圏のみ", "全国・海外"],
                        ["オフィス固定費", "高い", "低い"],
                    ]
                )),
            ]),
            SemanticSlide(layout: "SECTION_HEADER", title: "これからの課題"),
            SemanticSlide(layout: "TITLE_AND_BODY", title: "乗り越えるべき3つの壁", bodies: [
                SemanticBody(bullets: [
                    "孤立：雑談の消失がつながりを弱める",
                    "評価：時間ではなく成果で測る仕組みづくり",
                    "育成：背中を見て学ぶ機会の再設計",
                ]),
            ]),
            SemanticSlide(layout: "MAIN_POINT", title: "働き方は、もう元には戻らない", bodies: [
                SemanticBody(text: "問われているのは可否ではなく、==いかに使いこなすか==。"),
            ]),
        ])
    }

    /// The example as deterministic JSON (sorted keys, unescaped slashes — stable prompt cache,
    /// URL-clean), derived from the typed deck. Matches `A2UIExample.json`'s conventions.
    public static func exampleDeckJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return (try? encoder.encode(exampleDeck())).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// The system-instruction block: schema (what's allowed) + the worked example wrapped in the
    /// same `---BEGIN/END---` markers A2UI uses. The package owns this composition and pins the
    /// example to the schema with tests — hosts attach one block instead of hand-rolling the prompt.
    public static func promptBlock() -> String {
        let schema = (try? jsonSchemaData()).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        let schemaSection = """
        ### SLIDE DECK SCHEMA:
        The `deck_json` argument MUST validate against this JSON Schema:
        \(schema)
        """
        let example = GSlidesExampleFormatter.format(
            name: "EXAMPLE DECK (match its variety, density and layout usage — not its content)",
            content: exampleDeckJSON()
        )
        return "\(schemaSection)\n\n### Examples:\n\(example)"
    }
}

/// Wraps a few-shot example in `---BEGIN {name}--- / ---END {name}---` markers — the same marker
/// format as A2UI's `A2UIExampleFormatter` (the Python `load_examples()` convention).
public enum GSlidesExampleFormatter {
    public static func format(name: String, content: String) -> String {
        "---BEGIN \(name)---\n\(content)\n---END \(name)---"
    }
}
