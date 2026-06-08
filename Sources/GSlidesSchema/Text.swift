public struct TextContent: Codable, Hashable, Sendable {
    public var textElements: [TextElement]?
    /// Bulleted lists in this text, keyed by list ID (referenced by `Bullet.listId`).
    public var lists: [String: List]?

    public init(textElements: [TextElement]? = nil, lists: [String: List]? = nil) {
        self.textElements = textElements
        self.lists = lists
    }
}

public struct TextElement: Codable, Hashable, Sendable {
    public var startIndex: Int?
    public var endIndex: Int?
    public var paragraphMarker: ParagraphMarker?
    public var textRun: TextRun?
    public var autoText: AutoText?

    public init(
        startIndex: Int? = nil,
        endIndex: Int? = nil,
        paragraphMarker: ParagraphMarker? = nil,
        textRun: TextRun? = nil,
        autoText: AutoText? = nil
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.paragraphMarker = paragraphMarker
        self.textRun = textRun
        self.autoText = autoText
    }
}

public struct AutoTextType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "TYPE_UNSPECIFIED")
    public static let slideNumber = Self(rawValue: "SLIDE_NUMBER")

    public static var knownValues: [Self] { [.unspecified, .slideNumber] }
}

/// Dynamic text (e.g. slide number) resolved at render time.
public struct AutoText: Codable, Hashable, Sendable {
    public var type: AutoTextType?
    public var content: String?
    public var style: TextStyle?

    public init(type: AutoTextType? = nil, content: String? = nil, style: TextStyle? = nil) {
        self.type = type
        self.content = content
        self.style = style
    }
}

/// A bulleted list's per-nesting-level styling, keyed by depth (0-based, as string keys).
public struct List: Codable, Hashable, Sendable {
    public var listId: String?
    public var nestingLevel: [String: NestingLevel]?

    public init(listId: String? = nil, nestingLevel: [String: NestingLevel]? = nil) {
        self.listId = listId
        self.nestingLevel = nestingLevel
    }
}

public struct NestingLevel: Codable, Hashable, Sendable {
    public var bulletStyle: TextStyle?

    public init(bulletStyle: TextStyle? = nil) {
        self.bulletStyle = bulletStyle
    }
}

public struct TextRun: Codable, Hashable, Sendable {
    public var content: String?
    public var style: TextStyle?

    public init(content: String? = nil, style: TextStyle? = nil) {
        self.content = content
        self.style = style
    }
}

public struct ParagraphMarker: Codable, Hashable, Sendable {
    public var style: ParagraphStyle?
    public var bullet: Bullet?

    public init(style: ParagraphStyle? = nil, bullet: Bullet? = nil) {
        self.style = style
        self.bullet = bullet
    }
}

public struct Bullet: Codable, Hashable, Sendable {
    public var listId: String?
    public var nestingLevel: Int?
    public var glyph: String?
    public var bulletStyle: TextStyle?

    public init(
        listId: String? = nil,
        nestingLevel: Int? = nil,
        glyph: String? = nil,
        bulletStyle: TextStyle? = nil
    ) {
        self.listId = listId
        self.nestingLevel = nestingLevel
        self.glyph = glyph
        self.bulletStyle = bulletStyle
    }
}

public struct BaselineOffset: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "BASELINE_OFFSET_UNSPECIFIED")
    public static let none = Self(rawValue: "NONE")
    public static let superscript = Self(rawValue: "SUPERSCRIPT")
    public static let `subscript` = Self(rawValue: "SUBSCRIPT")

    public static var knownValues: [Self] { [.unspecified, .none, .superscript, .subscript] }
}

public struct TextStyle: Codable, Hashable, Sendable {
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var strikethrough: Bool?
    public var smallCaps: Bool?
    public var baselineOffset: BaselineOffset?
    public var fontFamily: String?
    public var fontSize: Dimension?
    public var foregroundColor: OptionalColor?
    public var backgroundColor: OptionalColor?
    public var weightedFontFamily: WeightedFontFamily?
    public var link: Link?

    public init(
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil,
        strikethrough: Bool? = nil,
        smallCaps: Bool? = nil,
        baselineOffset: BaselineOffset? = nil,
        fontFamily: String? = nil,
        fontSize: Dimension? = nil,
        foregroundColor: OptionalColor? = nil,
        backgroundColor: OptionalColor? = nil,
        weightedFontFamily: WeightedFontFamily? = nil,
        link: Link? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.smallCaps = smallCaps
        self.baselineOffset = baselineOffset
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.weightedFontFamily = weightedFontFamily
        self.link = link
    }
}

public struct Alignment: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "ALIGNMENT_UNSPECIFIED")
    public static let start = Self(rawValue: "START")
    public static let center = Self(rawValue: "CENTER")
    public static let end = Self(rawValue: "END")
    public static let justified = Self(rawValue: "JUSTIFIED")

    public static var knownValues: [Self] { [.unspecified, .start, .center, .end, .justified] }
}

public struct ParagraphStyle: Codable, Hashable, Sendable {
    public var alignment: Alignment?
    public var lineSpacing: Double?
    public var indentStart: Dimension?
    public var indentEnd: Dimension?
    public var indentFirstLine: Dimension?
    public var spaceAbove: Dimension?
    public var spaceBelow: Dimension?

    public init(
        alignment: Alignment? = nil,
        lineSpacing: Double? = nil,
        indentStart: Dimension? = nil,
        indentEnd: Dimension? = nil,
        indentFirstLine: Dimension? = nil,
        spaceAbove: Dimension? = nil,
        spaceBelow: Dimension? = nil
    ) {
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.indentStart = indentStart
        self.indentEnd = indentEnd
        self.indentFirstLine = indentFirstLine
        self.spaceAbove = spaceAbove
        self.spaceBelow = spaceBelow
    }
}
