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
    /// The notes page for this slide (indirect to break the Page ⇄ SlideProperties cycle).
    public var notesPage: Indirect<Page>?

    public init(
        layoutObjectId: String? = nil,
        masterObjectId: String? = nil,
        isSkipped: Bool? = nil,
        notesPage: Page? = nil
    ) {
        self.layoutObjectId = layoutObjectId
        self.masterObjectId = masterObjectId
        self.isSkipped = isSkipped
        self.notesPage = notesPage.map(Indirect.init)
    }
}

/// Boxes a recursive Codable value (notesPage is a full Page).
public struct Indirect<Wrapped: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    private final class Box: @unchecked Sendable { let value: Wrapped; init(_ value: Wrapped) { self.value = value } }
    private let box: Box
    public var value: Wrapped { box.value }

    public init(_ value: Wrapped) { box = Box(value) }
    public init(from decoder: any Decoder) throws {
        box = Box(try Wrapped(from: decoder))
    }
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
    public static func == (lhs: Indirect, rhs: Indirect) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }
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
    public var pageProperties: PageProperties?
    public var slideProperties: SlideProperties?
    public var layoutProperties: LayoutProperties?
    public var masterProperties: MasterProperties?
    public var notesProperties: NotesProperties?

    public init(
        objectId: String,
        pageType: PageType? = nil,
        pageElements: [PageElement]? = nil,
        pageProperties: PageProperties? = nil,
        slideProperties: SlideProperties? = nil,
        layoutProperties: LayoutProperties? = nil,
        masterProperties: MasterProperties? = nil,
        notesProperties: NotesProperties? = nil
    ) {
        self.objectId = objectId
        self.pageType = pageType
        self.pageElements = pageElements
        self.pageProperties = pageProperties
        self.slideProperties = slideProperties
        self.layoutProperties = layoutProperties
        self.masterProperties = masterProperties
        self.notesProperties = notesProperties
    }

    // Real presentations.get always carries objectId, but sparse fixtures (e.g. a notesPage
    // stub with only notesProperties) may omit it — decode tolerantly rather than crash.
    private enum CodingKeys: String, CodingKey {
        case objectId, pageType, pageElements, pageProperties
        case slideProperties, layoutProperties, masterProperties, notesProperties
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        objectId = try c.decodeIfPresent(String.self, forKey: .objectId) ?? ""
        pageType = try c.decodeIfPresent(PageType.self, forKey: .pageType)
        pageElements = try c.decodeIfPresent([PageElement].self, forKey: .pageElements)
        pageProperties = try c.decodeIfPresent(PageProperties.self, forKey: .pageProperties)
        slideProperties = try c.decodeIfPresent(SlideProperties.self, forKey: .slideProperties)
        layoutProperties = try c.decodeIfPresent(LayoutProperties.self, forKey: .layoutProperties)
        masterProperties = try c.decodeIfPresent(MasterProperties.self, forKey: .masterProperties)
        notesProperties = try c.decodeIfPresent(NotesProperties.self, forKey: .notesProperties)
    }
}
