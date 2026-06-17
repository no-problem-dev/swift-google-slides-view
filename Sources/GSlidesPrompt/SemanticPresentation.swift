import GSlidesSchema

/// The LLM generation contract: the semantic layer of the profile.
/// Models emit layout intent and placeholder content — never geometry.
/// Field order mirrors generation order: layout → title → subtitle → bodies.
public struct SemanticPresentation: Codable, Equatable, Sendable {
    public var title: String
    public var slides: [SemanticSlide]

    public init(title: String, slides: [SemanticSlide]) {
        self.title = title
        self.slides = slides
    }
}

public struct SemanticSlide: Codable, Equatable, Sendable {
    /// Raw PredefinedLayout value; omitted → inferred by LayoutMatcher.
    public var layout: String?
    public var title: String?
    /// Emphasized title (drives MAIN_POINT / BIG_NUMBER inference).
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
    /// Numeric stat cards (実績の図解): each renders as a big value + label + optional proportional
    /// bar, composed from native text/shape elements (no external image). Drives a data-visual look
    /// for metrics slides beyond a single big number. nil/empty → the body falls back to text/bullets.
    public var metrics: [SemanticMetric]?
    /// A column (vertical bar) chart for comparing categories or a time series (成長/推移) — bars sized
    /// proportionally, drawn from native shapes/text (no external image). nil → no chart.
    public var chart: SemanticChart?
    /// A left-to-right process flow (プロセス/手順): step cards joined by arrows, drawn from native
    /// shapes/text/lines (no external image). nil/empty → no flow.
    public var steps: [SemanticStep]?
    /// A testimonial / pull quote (顧客の声・社会的証明): a large quotation set off by an accent quote
    /// mark, with an attribution. nil → no quote.
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

/// A testimonial / pull quote: the `text` itself, plus an optional `author` and their `role` (company
/// or title) for the attribution line. Rendered large with a decorative quote mark.
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

/// One step of a process flow: a short `label` (the step name) and an optional `caption` (a one-line
/// detail under it). Rendered as a card; consecutive steps are joined by an arrow.
public struct SemanticStep: Codable, Equatable, Sendable {
    public var label: String
    public var caption: String?

    public init(label: String, caption: String? = nil) {
        self.label = label
        self.caption = caption
    }
}

/// A single-series column chart: each bar carries a `value` (its height, relative to the largest),
/// a `label` (the category/period under it, e.g. "2023"), and an optional `caption` overriding the
/// printed value above the bar (e.g. "¥1.2億"; otherwise the value is printed). Up to a handful of
/// bars — for a credible 成長/推移 read without a chart engine or Sheets.
public struct SemanticChart: Codable, Equatable, Sendable {
    /// How the series is drawn: `.bar` columns (default) for category comparison, `.line` for a
    /// trend/推移 read. Same data shape either way.
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

/// One numeric stat for a metrics visual: a `value` (kept as a string so "1,200" / "98.5" / "3×"
/// render verbatim), an optional `unit` shown smaller next to it, a `label` underneath, and an
/// optional `ratio` (0–1) that draws a proportional accent bar (a share/achievement read).
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

/// One bullet line with an optional nesting level (0 = top level). Decodes from EITHER a bare
/// string (level 0) or an object `{text, level}`, so flat lists stay terse and nested lists are
/// explicit — and encodes back the same way (level 0 → string), keeping example JSON compact.
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

/// A simple table: an optional header row plus rows of cell strings. Expands to a profile `Table`
/// element (header row emphasized). Ragged rows are padded to the widest row.
public struct SemanticTable: Codable, Equatable, Sendable {
    public var headers: [String]?
    public var rows: [[String]]

    public init(headers: [String]? = nil, rows: [[String]] = []) {
        self.headers = headers
        self.rows = rows
    }
}
