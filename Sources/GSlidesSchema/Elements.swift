/// Profile subset of the PageElement union: shape / image / line / table / elementGroup.
/// An element where every known union member is nil is an out-of-profile element
/// (e.g. video, wordArt) — first-class for renderers as `kind == .unknown`.
public struct PageElement: Codable, Hashable, Sendable {
    public var objectId: String
    public var size: Size?
    public var transform: AffineTransform?
    public var title: String?
    public var description: String?
    public var shape: Shape?
    public var image: Image?
    public var line: Line?
    public var table: Table?
    public var elementGroup: Group?

    public init(
        objectId: String,
        size: Size? = nil,
        transform: AffineTransform? = nil,
        title: String? = nil,
        description: String? = nil,
        shape: Shape? = nil,
        image: Image? = nil,
        line: Line? = nil,
        table: Table? = nil,
        elementGroup: Group? = nil
    ) {
        self.objectId = objectId
        self.size = size
        self.transform = transform
        self.title = title
        self.description = description
        self.shape = shape
        self.image = image
        self.line = line
        self.table = table
        self.elementGroup = elementGroup
    }

    public enum Kind: Hashable, Sendable {
        case shape(Shape)
        case image(Image)
        case line(Line)
        case table(Table)
        case elementGroup(Group)
        case unknown
    }

    public var kind: Kind {
        if let shape { return .shape(shape) }
        if let image { return .image(image) }
        if let line { return .line(line) }
        if let table { return .table(table) }
        if let elementGroup { return .elementGroup(elementGroup) }
        return .unknown
    }
}

public struct PlaceholderType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let none = Self(rawValue: "NONE")
    public static let body = Self(rawValue: "BODY")
    public static let chart = Self(rawValue: "CHART")
    public static let clipArt = Self(rawValue: "CLIP_ART")
    public static let centeredTitle = Self(rawValue: "CENTERED_TITLE")
    public static let diagram = Self(rawValue: "DIAGRAM")
    public static let dateAndTime = Self(rawValue: "DATE_AND_TIME")
    public static let footer = Self(rawValue: "FOOTER")
    public static let header = Self(rawValue: "HEADER")
    public static let media = Self(rawValue: "MEDIA")
    public static let object = Self(rawValue: "OBJECT")
    public static let picture = Self(rawValue: "PICTURE")
    public static let slideNumber = Self(rawValue: "SLIDE_NUMBER")
    public static let subtitle = Self(rawValue: "SUBTITLE")
    public static let table = Self(rawValue: "TABLE")
    public static let title = Self(rawValue: "TITLE")
    public static let slideImage = Self(rawValue: "SLIDE_IMAGE")

    public static var knownValues: [Self] {
        [
            .none, .body, .chart, .clipArt, .centeredTitle, .diagram,
            .dateAndTime, .footer, .header, .media, .object, .picture,
            .slideNumber, .subtitle, .table, .title, .slideImage,
        ]
    }
}

public struct Placeholder: Codable, Hashable, Sendable {
    public var type: PlaceholderType?
    public var index: Int?
    public var parentObjectId: String?

    public init(type: PlaceholderType? = nil, index: Int? = nil, parentObjectId: String? = nil) {
        self.type = type
        self.index = index
        self.parentObjectId = parentObjectId
    }
}

public struct ShapeType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "TYPE_UNSPECIFIED")
    public static let textBox = Self(rawValue: "TEXT_BOX")
    public static let rectangle = Self(rawValue: "RECTANGLE")
    public static let roundRectangle = Self(rawValue: "ROUND_RECTANGLE")
    public static let ellipse = Self(rawValue: "ELLIPSE")
    public static let triangle = Self(rawValue: "TRIANGLE")
    public static let diamond = Self(rawValue: "DIAMOND")
    public static let rightArrow = Self(rawValue: "RIGHT_ARROW")
    public static let leftArrow = Self(rawValue: "LEFT_ARROW")
    public static let upArrow = Self(rawValue: "UP_ARROW")
    public static let downArrow = Self(rawValue: "DOWN_ARROW")
    public static let star5 = Self(rawValue: "STAR_5")
    public static let cloud = Self(rawValue: "CLOUD")
    public static let heart = Self(rawValue: "HEART")

    public static var knownValues: [Self] {
        [
            .unspecified, .textBox, .rectangle, .roundRectangle, .ellipse,
            .triangle, .diamond, .rightArrow, .leftArrow, .upArrow, .downArrow,
            .star5, .cloud, .heart,
        ]
    }
}

public struct AutofitType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "AUTOFIT_TYPE_UNSPECIFIED")
    public static let none = Self(rawValue: "NONE")
    public static let textAutofit = Self(rawValue: "TEXT_AUTOFIT")
    public static let shapeAutofit = Self(rawValue: "SHAPE_AUTOFIT")

    public static var knownValues: [Self] { [.unspecified, .none, .textAutofit, .shapeAutofit] }
}

public struct Autofit: Codable, Hashable, Sendable {
    public var autofitType: AutofitType?
    public var fontScale: Double?
    public var lineSpacingReduction: Double?

    public init(
        autofitType: AutofitType? = nil,
        fontScale: Double? = nil,
        lineSpacingReduction: Double? = nil
    ) {
        self.autofitType = autofitType
        self.fontScale = fontScale
        self.lineSpacingReduction = lineSpacingReduction
    }
}

public struct ShapeBackgroundFill: Codable, Hashable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct Outline: Codable, Hashable, Sendable {
    public var outlineFill: OutlineFill?
    public var weight: Dimension?

    public init(outlineFill: OutlineFill? = nil, weight: Dimension? = nil) {
        self.outlineFill = outlineFill
        self.weight = weight
    }
}

public struct OutlineFill: Codable, Hashable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct ShapeProperties: Codable, Hashable, Sendable {
    public var shapeBackgroundFill: ShapeBackgroundFill?
    public var outline: Outline?
    public var autofit: Autofit?

    public init(
        shapeBackgroundFill: ShapeBackgroundFill? = nil,
        outline: Outline? = nil,
        autofit: Autofit? = nil
    ) {
        self.shapeBackgroundFill = shapeBackgroundFill
        self.outline = outline
        self.autofit = autofit
    }
}

public struct Shape: Codable, Hashable, Sendable {
    public var shapeType: ShapeType?
    public var text: TextContent?
    public var placeholder: Placeholder?
    public var shapeProperties: ShapeProperties?

    public init(
        shapeType: ShapeType? = nil,
        text: TextContent? = nil,
        placeholder: Placeholder? = nil,
        shapeProperties: ShapeProperties? = nil
    ) {
        self.shapeType = shapeType
        self.text = text
        self.placeholder = placeholder
        self.shapeProperties = shapeProperties
    }
}

public struct Image: Codable, Hashable, Sendable {
    public var contentUrl: String?
    public var sourceUrl: String?
    public var placeholder: Placeholder?

    public init(contentUrl: String? = nil, sourceUrl: String? = nil, placeholder: Placeholder? = nil) {
        self.contentUrl = contentUrl
        self.sourceUrl = sourceUrl
        self.placeholder = placeholder
    }
}

public struct LineProperties: Codable, Hashable, Sendable {
    public var lineFill: LineFill?
    public var weight: Dimension?

    public init(lineFill: LineFill? = nil, weight: Dimension? = nil) {
        self.lineFill = lineFill
        self.weight = weight
    }
}

public struct LineFill: Codable, Hashable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct Line: Codable, Hashable, Sendable {
    public var lineProperties: LineProperties?

    public init(lineProperties: LineProperties? = nil) {
        self.lineProperties = lineProperties
    }
}

public struct TableCellLocation: Codable, Hashable, Sendable {
    public var rowIndex: Int?
    public var columnIndex: Int?

    public init(rowIndex: Int? = nil, columnIndex: Int? = nil) {
        self.rowIndex = rowIndex
        self.columnIndex = columnIndex
    }
}

public struct TableCell: Codable, Hashable, Sendable {
    public var location: TableCellLocation?
    public var rowSpan: Int?
    public var columnSpan: Int?
    public var text: TextContent?

    public init(
        location: TableCellLocation? = nil,
        rowSpan: Int? = nil,
        columnSpan: Int? = nil,
        text: TextContent? = nil
    ) {
        self.location = location
        self.rowSpan = rowSpan
        self.columnSpan = columnSpan
        self.text = text
    }
}

public struct TableRow: Codable, Hashable, Sendable {
    public var rowHeight: Dimension?
    public var tableCells: [TableCell]?

    public init(rowHeight: Dimension? = nil, tableCells: [TableCell]? = nil) {
        self.rowHeight = rowHeight
        self.tableCells = tableCells
    }
}

public struct Table: Codable, Hashable, Sendable {
    public var rows: Int?
    public var columns: Int?
    public var tableRows: [TableRow]?

    public init(rows: Int? = nil, columns: Int? = nil, tableRows: [TableRow]? = nil) {
        self.rows = rows
        self.columns = columns
        self.tableRows = tableRows
    }
}

public struct Group: Codable, Hashable, Sendable {
    public var children: [PageElement]?

    public init(children: [PageElement]? = nil) {
        self.children = children
    }
}
