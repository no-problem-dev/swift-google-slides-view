import Foundation

/// 手書き JSON ではなく **Swift の型システムから** 構築するフューショット例 — `A2UIExample` のスライドプレゼンテーション版。
/// 手書きの文字列は静かにズレてバリデーション違反になる（レイアウト名の誤りやスキーマから削除されたフィールド）。
/// 型付きの `SemanticPresentation` 値から構築してシリアライズすることで構造的な正当性を保証し、テストで固定する。
extension GSlidesGenerationContract {

    /// 正規例であり品質基準でもある。モデルには散文ルールを読ませるのではなく、このプレゼンテーションの
    /// 多様性・密度・レイアウト使用を MATCH するよう指示する — デモンストレーションによる教示。
    /// 型付き値から構築。ローカライズ済み（ホストのロールプロンプトが言語を設定し、コンテンツがそれを示す）。
    public static func examplePresentation() -> SemanticPresentation {
        SemanticPresentation(title: "リモートワーク時代の生産性", slides: [
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

    /// 型付きプレゼンテーションから導出した決定論的 JSON（ソートキー・スラッシュエスケープなし — 安定したプロンプトキャッシュ、URL クリーン）。
    /// `A2UIExample.json` の規約に準拠。
    public static func examplePresentationJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return (try? encoder.encode(examplePresentation())).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// システム指示ブロック: スキーマ（許可される内容）+ A2UI と同じ `---BEGIN/END---` マーカーで包んだワーク済み例。
    /// パッケージがこの合成を所有し、テストでスキーマと例を固定する —
    /// ホストはプロンプトを手で組む代わりにこの 1 ブロックを添付する。
    public static func promptBlock() -> String {
        let schema = (try? jsonSchemaData()).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        let schemaSection = """
        ### SLIDE PRESENTATION SCHEMA:
        The `presentation_json` argument MUST validate against this JSON Schema:
        \(schema)
        """
        let example = GSlidesExampleFormatter.format(
            name: "EXAMPLE PRESENTATION (match its variety, density and layout usage — not its content)",
            content: examplePresentationJSON()
        )
        return "\(schemaSection)\n\n### Examples:\n\(example)"
    }
}

/// フューショット例を `---BEGIN {name}--- / ---END {name}---` マーカーで包む —
/// A2UI の `A2UIExampleFormatter`（Python `load_examples()` 規約）と同じマーカー形式。
public enum GSlidesExampleFormatter {
    public static func format(name: String, content: String) -> String {
        "---BEGIN \(name)---\n\(content)\n---END \(name)---"
    }
}
