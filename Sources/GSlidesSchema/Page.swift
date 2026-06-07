public struct PageType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let slide = Self(rawValue: "SLIDE")
    public static let master = Self(rawValue: "MASTER")
    public static let layout = Self(rawValue: "LAYOUT")
    public static let notes = Self(rawValue: "NOTES")
    public static let notesMaster = Self(rawValue: "NOTES_MASTER")

    public static var knownValues: [Self] { [.slide, .master, .layout, .notes, .notesMaster] }
}

public struct SlideProperties: Codable, Hashable, Sendable {
    public var layoutObjectId: String?
    public var masterObjectId: String?
    public var isSkipped: Bool?

    public init(layoutObjectId: String? = nil, masterObjectId: String? = nil, isSkipped: Bool? = nil) {
        self.layoutObjectId = layoutObjectId
        self.masterObjectId = masterObjectId
        self.isSkipped = isSkipped
    }
}

public struct LayoutProperties: Codable, Hashable, Sendable {
    public var name: String?
    public var displayName: String?
    public var masterObjectId: String?

    public init(name: String? = nil, displayName: String? = nil, masterObjectId: String? = nil) {
        self.name = name
        self.displayName = displayName
        self.masterObjectId = masterObjectId
    }
}

public struct Page: Codable, Hashable, Sendable {
    public var objectId: String
    public var pageType: PageType?
    public var pageElements: [PageElement]?
    public var slideProperties: SlideProperties?
    public var layoutProperties: LayoutProperties?

    public init(
        objectId: String,
        pageType: PageType? = nil,
        pageElements: [PageElement]? = nil,
        slideProperties: SlideProperties? = nil,
        layoutProperties: LayoutProperties? = nil
    ) {
        self.objectId = objectId
        self.pageType = pageType
        self.pageElements = pageElements
        self.slideProperties = slideProperties
        self.layoutProperties = layoutProperties
    }
}
