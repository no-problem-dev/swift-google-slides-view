import GSlidesSchema

/// What a model emits: layout intent and placeholder content, never geometry.
///
/// Keeping coordinates out of the model's hands is the point — `PresentationExpander` supplies them
/// from the template, so a generated deck is laid out by the same code as a fetched one. Field order
/// follows generation order: layout, title, subtitle, bodies.
public struct SemanticPresentation: Codable, Equatable, Sendable {
    public var title: String
    public var slides: [SemanticSlide]

    public init(title: String, slides: [SemanticSlide]) {
        self.title = title
        self.slides = slides
    }
}

public struct SemanticSlide: Codable, Equatable, Sendable {
    /// A raw `PredefinedLayout` value. Omit it and `LayoutMatcher` infers one from the content.
    ///
    /// A string, not the typed enum, because it comes straight from model output; the contract
    /// validates it against the allowed names.
    public var layout: String?
    public var title: String?
    /// Marks the title as oversized, which is what steers layout inference toward MAIN_POINT and
    /// BIG_NUMBER. Ignored when `layout` is set explicitly.
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
    /// A row of stat cards, each a large value with a label and an optional proportional bar.
    ///
    /// Drawn from native text and shape elements, so no external image is fetched. Takes over the
    /// whole body box: `text`, `bullets` and `imageUrl` on the same body are not drawn alongside it.
    /// When the body has no geometry this degrades to a labeled text list.
    public var metrics: [SemanticMetric]?
    /// A single-series chart for comparing categories or showing a trend, drawn from native shapes
    /// and text with no external image.
    ///
    /// Takes over the whole body box, and degrades to a labeled text list without geometry.
    public var chart: SemanticChart?
    /// A left-to-right process flow of arrow-joined step cards, drawn from native shapes, text and
    /// lines with no external image.
    ///
    /// Takes over the whole body box, and degrades to a numbered list without geometry.
    public var steps: [SemanticStep]?
    /// A testimonial drawn as a large pull quote with an accent quotation mark and an attribution line.
    ///
    /// Takes over the whole body box, and degrades to plain body text without geometry.
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

/// A testimonial: the quote itself, plus an optional author and role that form the attribution line.
///
/// With neither author nor role the attribution line is omitted entirely rather than left blank.
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

/// One step of a process flow: a short label, and an optional one-line caption beneath it.
///
/// Drawn as a card, with an arrow to the next step. A step with no caption centers its label.
public struct SemanticStep: Codable, Equatable, Sendable {
    public var label: String
    public var caption: String?

    public init(label: String, caption: String? = nil) {
        self.label = label
        self.caption = caption
    }
}

/// A single-series chart, sized relative to its own largest value.
///
/// Bars carry no axis scale — heights are proportional within the chart, so two charts side by side
/// are not comparable. Meant for a handful of bars that make a trend legible without a chart engine
/// or a linked spreadsheet.
public struct SemanticChart: Codable, Equatable, Sendable {
    /// How to draw the series. The data shape is identical either way, so switching is purely a
    /// presentation choice: columns compare categories, a line reads as a trend.
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

/// One statistic in a metrics visual.
///
/// `value` is a string, not a number, so "1,200", "98.5" and "3×" render exactly as written and
/// nothing reformats them. `unit` is set smaller beside it, `label` sits underneath, and `ratio`
/// — 0 to 1 — draws a proportional bar when present.
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

/// One bullet line, with an optional nesting level where 0 is top level.
///
/// Decodes from either a bare string, meaning level 0, or a `{text, level}` object, which keeps flat
/// lists terse and nested ones explicit. Encoding is symmetric — level 0 writes as a bare string —
/// so the worked example JSON stays compact.
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

/// A simple table: an optional header row and rows of cell strings.
///
/// Expands to a `Table` element with the header row emphasized. Rows of unequal length are padded
/// with empty cells to the widest row rather than rejected.
public struct SemanticTable: Codable, Equatable, Sendable {
    public var headers: [String]?
    public var rows: [[String]]

    public init(headers: [String]? = nil, rows: [[String]] = []) {
        self.headers = headers
        self.rows = rows
    }
}
