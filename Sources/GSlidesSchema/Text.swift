public struct TextContent: Codable, Hashable, Sendable {
    public var textElements: [TextElement]?

    public init(textElements: [TextElement]? = nil) {
        self.textElements = textElements
    }
}

public struct TextElement: Codable, Hashable, Sendable {
    public var startIndex: Int?
    public var endIndex: Int?
    public var paragraphMarker: ParagraphMarker?
    public var textRun: TextRun?

    public init(
        startIndex: Int? = nil,
        endIndex: Int? = nil,
        paragraphMarker: ParagraphMarker? = nil,
        textRun: TextRun? = nil
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.paragraphMarker = paragraphMarker
        self.textRun = textRun
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
        backgroundColor: OptionalColor? = nil
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
