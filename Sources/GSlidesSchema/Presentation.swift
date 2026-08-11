/// A predefined slide layout name defined by the Slides API.
///
/// Open-ended rather than a Swift enum, so a layout name decoded from the wire that this profile
/// does not list still re-encodes unchanged. Mirrors `google.apps.slides.v1.PredefinedLayout`.
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

/// Identifies the layout a slide uses — set exactly one of the two fields, never both.
///
/// `layoutId` is the objectId of a page in `Presentation.layouts`; `predefinedLayout` names a
/// built-in layout instead. Mirrors `google.apps.slides.v1.LayoutReference`.
public struct LayoutReference: Codable, Equatable, Sendable {
    public var layoutId: String?
    public var predefinedLayout: PredefinedLayout?

    public init(layoutId: String? = nil, predefinedLayout: PredefinedLayout? = nil) {
        self.layoutId = layoutId
        self.predefinedLayout = predefinedLayout
    }
}

/// The root of a Google Slides presentation: slides, layouts and masters.
///
/// Every field is optional, including ones the real API always returns, so an assembler can hold a
/// half-built presentation — a stream where slides arrive before the envelope, for example. A nil
/// therefore means "not received yet" as often as it means "absent".
/// Mirrors `google.apps.slides.v1.Presentation`.
public struct Presentation: Codable, Equatable, Sendable {
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
