import GSlidesSchema

/// LLM 生成コントラクト: プロファイルのセマンティックレイヤー。
/// モデルはレイアウトの意図とプレースホルダーコンテンツを出力する — ジオメトリは出力しない。
/// フィールド順は生成順を反映: layout → title → subtitle → bodies。
public struct SemanticPresentation: Codable, Equatable, Sendable {
    public var title: String
    public var slides: [SemanticSlide]

    public init(title: String, slides: [SemanticSlide]) {
        self.title = title
        self.slides = slides
    }
}

public struct SemanticSlide: Codable, Equatable, Sendable {
    /// 生の PredefinedLayout 値。省略時は LayoutMatcher が推論する。
    public var layout: String?
    public var title: String?
    /// 強調タイトル（MAIN_POINT / BIG_NUMBER の推論を駆動する）。
    public var big: Bool?
    public var subtitle: String?
    public var bodies: [SemanticBody]?

    public init(
        layout: String? = nil,
        title: String? = nil,
        big: Bool? = nil,
        subtitle: String? = nil,
        bodies: [SemanticBody]? = nil
    ) {
        self.layout = layout
        self.title = title
        self.big = big
        self.subtitle = subtitle
        self.bodies = bodies
    }
}

public struct SemanticBody: Codable, Equatable, Sendable {
    public var text: String?
    public var bullets: [SemanticBullet]?
    public var imageUrl: String?
    public var table: SemanticTable?
    /// 数値スタットカード（実績の図解）: 各カードは大きな値 + ラベル + オプションの比例バーで構成され、
    /// ネイティブのテキスト / シェイプ要素から描画する（外部画像なし）。単一の大きな数字を超える
    /// データビジュアルなメトリクススライドを実現する。nil / 空の場合はテキスト / バレットにフォールバックする。
    public var metrics: [SemanticMetric]?
    /// カテゴリ比較または時系列（成長/推移）用の縦棒チャート — 比例サイズのバーをネイティブシェイプ / テキストで描画する（外部画像なし）。nil → チャートなし。
    public var chart: SemanticChart?
    /// 左→右のプロセスフロー（プロセス/手順）: 矢印でつながるステップカードをネイティブシェイプ / テキスト / ラインで描画する（外部画像なし）。nil / 空 → フローなし。
    public var steps: [SemanticStep]?
    /// 推薦文 / プルクォート（顧客の声・社会的証明）: アクセント引用符で際立たせた大きな引用と帰属行。nil → 引用なし。
    public var quote: SemanticQuote?

    public init(
        text: String? = nil,
        bullets: [SemanticBullet]? = nil,
        imageUrl: String? = nil,
        table: SemanticTable? = nil,
        metrics: [SemanticMetric]? = nil,
        chart: SemanticChart? = nil,
        steps: [SemanticStep]? = nil,
        quote: SemanticQuote? = nil
    ) {
        self.text = text
        self.bullets = bullets
        self.imageUrl = imageUrl
        self.table = table
        self.metrics = metrics
        self.chart = chart
        self.steps = steps
        self.quote = quote
    }
}

/// 推薦文 / プルクォート: `text` 本文、オプションの `author`、帰属行用の `role`（会社または役職）。
/// 装飾的な引用符と共に大きく描画される。
public struct SemanticQuote: Codable, Equatable, Sendable {
    public var text: String
    public var author: String?
    public var role: String?

    public init(text: String, author: String? = nil, role: String? = nil) {
        self.text = text
        self.author = author
        self.role = role
    }
}

/// プロセスフローの 1 ステップ: 短い `label`（ステップ名）とオプションの `caption`（その下の 1 行説明）。
/// カードとして描画され、連続するステップは矢印で接続される。
public struct SemanticStep: Codable, Equatable, Sendable {
    public var label: String
    public var caption: String?

    public init(label: String, caption: String? = nil) {
        self.label = label
        self.caption = caption
    }
}

/// 単系列縦棒チャート: 各バーは `value`（最大値に対する相対高さ）、`label`（その下のカテゴリ/期間、例: "2023"）、
/// バー上の表示値を上書きするオプションの `caption`（例: "¥1.2億"。なければ value を表示）を持つ。
/// チャートエンジンや Sheets なしに成長/推移を説得力ある形で見せるための少数のバー。
public struct SemanticChart: Codable, Equatable, Sendable {
    /// 系列の描画方法: `.bar` 縦棒（デフォルト）はカテゴリ比較、`.line` 折れ線は推移の読み取りに使う。データ形状はどちらも同じ。
    public enum ChartType: String, Codable, Sendable {
        case bar
        case line
    }

    public var bars: [SemanticChartBar]
    public var type: ChartType

    public init(bars: [SemanticChartBar], type: ChartType = .bar) {
        self.bars = bars
        self.type = type
    }

    private enum CodingKeys: String, CodingKey { case bars, type }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bars = try container.decode([SemanticChartBar].self, forKey: .bars)
        type = try container.decodeIfPresent(ChartType.self, forKey: .type) ?? .bar
    }
}

public struct SemanticChartBar: Codable, Equatable, Sendable {
    public var label: String
    public var value: Double
    public var caption: String?

    public init(label: String, value: Double, caption: String? = nil) {
        self.label = label
        self.value = value
        self.caption = caption
    }
}

/// メトリクスビジュアルの 1 件の数値統計: `value`（文字列として保持し "1,200" / "98.5" / "3×" をそのまま表示）、
/// 隣に小さく表示するオプションの `unit`、その下の `label`、割合/達成度バーを描くオプションの `ratio`（0–1）。
public struct SemanticMetric: Codable, Equatable, Sendable {
    public var label: String
    public var value: String
    public var unit: String?
    public var ratio: Double?

    public init(label: String, value: String, unit: String? = nil, ratio: Double? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
        self.ratio = ratio
    }
}

/// オプションのネストレベル（0 = トップレベル）を持つ 1 バレット行。裸の文字列（レベル 0）または
/// `{text, level}` オブジェクトのどちらからでもデコードし、フラットリストは簡潔に、ネストリストは明示的に保つ。
/// 同じ方法でエンコードし（レベル 0 → 文字列）、例 JSON をコンパクトに維持する。
public struct SemanticBullet: Equatable, Sendable {
    public var text: String
    public var level: Int

    public init(_ text: String, level: Int = 0) {
        self.text = text
        self.level = level
    }
}

extension SemanticBullet: Codable {
    private enum CodingKeys: String, CodingKey { case text, level }

    public init(from decoder: any Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self.text = string
            self.level = 0
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        if level == 0 {
            var container = encoder.singleValueContainer()
            try container.encode(text)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encode(level, forKey: .level)
        }
    }
}

extension SemanticBullet: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

/// シンプルなテーブル: オプションのヘッダー行 + セル文字列の行。プロファイルの `Table` 要素に展開する
/// （ヘッダー行は強調）。参差な行は最大幅にパディングする。
public struct SemanticTable: Codable, Equatable, Sendable {
    public var headers: [String]?
    public var rows: [[String]]

    public init(headers: [String]? = nil, rows: [[String]] = []) {
        self.headers = headers
        self.rows = rows
    }
}
