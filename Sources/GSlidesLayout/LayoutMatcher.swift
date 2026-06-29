import GSlidesSchema

/// レイアウト推論に使うスライドのセマンティック内容。
/// md2googleslides の SlideDefinition を Swift に移植したもの（マッチングルールが読むフィールドのみ）。
public struct SlideContent: Equatable, Sendable {
    public struct Text: Equatable, Sendable {
        public var rawText: String
        public var big: Bool

        public init(_ rawText: String, big: Bool = false) {
            self.rawText = rawText
            self.big = big
        }
    }

    public struct Body: Equatable, Sendable {
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

/// コンテンツ → 定義済みレイアウトのマッチング。
/// md2googleslides src/layout/match_layout.ts を忠実に移植（Apache-2.0、NOTICE 参照）。
/// ルール順序が重要 — 最初にマッチしたものが採用される。
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

    /// レイアウト参照を解決する。ルールベース推論より明示的なカスタムレイアウト
    /// （layoutProperties.displayName で照合）を優先する。
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
