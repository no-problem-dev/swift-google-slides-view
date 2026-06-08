public struct PredefinedLayout: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "PREDEFINED_LAYOUT_UNSPECIFIED")
    public static let blank = Self(rawValue: "BLANK")
    public static let captionOnly = Self(rawValue: "CAPTION_ONLY")
    public static let title = Self(rawValue: "TITLE")
    public static let titleAndBody = Self(rawValue: "TITLE_AND_BODY")
    public static let titleAndTwoColumns = Self(rawValue: "TITLE_AND_TWO_COLUMNS")
    public static let titleOnly = Self(rawValue: "TITLE_ONLY")
    public static let sectionHeader = Self(rawValue: "SECTION_HEADER")
    public static let sectionTitleAndDescription = Self(rawValue: "SECTION_TITLE_AND_DESCRIPTION")
    public static let oneColumnText = Self(rawValue: "ONE_COLUMN_TEXT")
    public static let mainPoint = Self(rawValue: "MAIN_POINT")
    public static let bigNumber = Self(rawValue: "BIG_NUMBER")

    public static var knownValues: [Self] {
        [
            .unspecified, .blank, .captionOnly, .title, .titleAndBody,
            .titleAndTwoColumns, .titleOnly, .sectionHeader,
            .sectionTitleAndDescription, .oneColumnText, .mainPoint, .bigNumber,
        ]
    }
}

public struct LayoutReference: Codable, Hashable, Sendable {
    public var layoutId: String?
    public var predefinedLayout: PredefinedLayout?

    public init(layoutId: String? = nil, predefinedLayout: PredefinedLayout? = nil) {
        self.layoutId = layoutId
        self.predefinedLayout = predefinedLayout
    }
}

public struct Presentation: Codable, Hashable, Sendable {
    public var presentationId: String?
    public var title: String?
    public var locale: String?
    public var revisionId: String?
    public var pageSize: Size?
    public var slides: [Page]?
    public var layouts: [Page]?
    public var masters: [Page]?
    public var notesMaster: Page?

    public init(
        presentationId: String? = nil,
        title: String? = nil,
        locale: String? = nil,
        revisionId: String? = nil,
        pageSize: Size? = nil,
        slides: [Page]? = nil,
        layouts: [Page]? = nil,
        masters: [Page]? = nil,
        notesMaster: Page? = nil
    ) {
        self.presentationId = presentationId
        self.title = title
        self.locale = locale
        self.revisionId = revisionId
        self.pageSize = pageSize
        self.slides = slides
        self.layouts = layouts
        self.masters = masters
        self.notesMaster = notesMaster
    }
}
