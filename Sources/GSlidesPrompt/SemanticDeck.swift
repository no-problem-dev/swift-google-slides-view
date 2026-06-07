import GSlidesSchema

/// The LLM generation contract: the semantic layer of the profile.
/// Models emit layout intent and placeholder content — never geometry.
/// Field order mirrors generation order: layout → title → subtitle → bodies.
public struct SemanticDeck: Codable, Hashable, Sendable {
    public var title: String
    public var slides: [SemanticSlide]

    public init(title: String, slides: [SemanticSlide]) {
        self.title = title
        self.slides = slides
    }
}

public struct SemanticSlide: Codable, Hashable, Sendable {
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

public struct SemanticBody: Codable, Hashable, Sendable {
    public var text: String?
    public var bullets: [String]?
    public var imageUrl: String?

    public init(text: String? = nil, bullets: [String]? = nil, imageUrl: String? = nil) {
        self.text = text
        self.bullets = bullets
        self.imageUrl = imageUrl
    }
}
