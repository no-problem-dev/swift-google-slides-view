import GSlidesSchema

/// Semantic slide content used for layout inference.
/// Swift port of md2googleslides' SlideDefinition (the fields its matching rules read).
public struct SlideContent: Hashable, Sendable {
    public struct Text: Hashable, Sendable {
        public var rawText: String
        public var big: Bool

        public init(_ rawText: String, big: Bool = false) {
            self.rawText = rawText
            self.big = big
        }
    }

    public struct Body: Hashable, Sendable {
        public var text: Text?
        public var imageCount: Int
        public var videoCount: Int

        public init(text: Text? = nil, imageCount: Int = 0, videoCount: Int = 0) {
            self.text = text
            self.imageCount = imageCount
            self.videoCount = videoCount
        }
    }

    public var title: Text?
    public var subtitle: Text?
    public var bodies: [Body]
    public var tableCount: Int
    public var customLayout: String?

    public init(
        title: Text? = nil,
        subtitle: Text? = nil,
        bodies: [Body] = [],
        tableCount: Int = 0,
        customLayout: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.bodies = bodies
        self.tableCount = tableCount
        self.customLayout = customLayout
    }
}

/// Content → predefined layout matching.
/// Faithful port of md2googleslides src/layout/match_layout.ts (Apache-2.0, see NOTICE);
/// rule order matters — first match wins.
public enum LayoutMatcher {
    public static func match(_ slide: SlideContent) -> PredefinedLayout {
        if hasText(slide.title), hasText(slide.subtitle), !hasContent(slide) {
            return .title
        }
        if hasBigTitle(slide), !hasContent(slide) {
            return .mainPoint
        }
        if hasText(slide.title), !hasText(slide.subtitle), !hasContent(slide) {
            return .sectionHeader
        }
        if hasText(slide.title), hasText(slide.subtitle), hasTextContent(slide) {
            return .sectionTitleAndDescription
        }
        if hasBigTitle(slide), hasTextContent(slide) {
            return .bigNumber
        }
        if hasText(slide.title), slide.bodies.count == 2 {
            return .titleAndTwoColumns
        }
        if hasText(slide.title) || !slide.bodies.isEmpty {
            return .titleAndBody
        }
        return .blank
    }

    /// Resolves a layout reference, preferring an explicit custom layout
    /// (matched by layoutProperties.displayName) over rule-based inference.
    public static func reference(
        for slide: SlideContent,
        in presentation: Presentation? = nil
    ) -> LayoutReference {
        if let customLayout = slide.customLayout,
           let layout = presentation?.layouts?.first(where: {
               $0.layoutProperties?.displayName == customLayout
           }) {
            return LayoutReference(layoutId: layout.objectId)
        }
        return LayoutReference(predefinedLayout: match(slide))
    }

    private static func hasText(_ text: SlideContent.Text?) -> Bool {
        text.map { !$0.rawText.isEmpty } ?? false
    }

    private static func hasBigTitle(_ slide: SlideContent) -> Bool {
        hasText(slide.title) && slide.title?.big == true
    }

    private static func hasTextContent(_ slide: SlideContent) -> Bool {
        !slide.bodies.isEmpty
    }

    private static func hasContent(_ slide: SlideContent) -> Bool {
        !slide.bodies.isEmpty || slide.tableCount != 0
    }
}
