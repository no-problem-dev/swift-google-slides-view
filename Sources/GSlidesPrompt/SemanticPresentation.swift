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

    public init(
        text: String? = nil,
        bullets: [SemanticBullet]? = nil,
        imageUrl: String? = nil,
        table: SemanticTable? = nil
    ) {
        self.text = text
        self.bullets = bullets
        self.imageUrl = imageUrl
        self.table = table
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
