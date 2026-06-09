/// Profile subset of the PageElement union: shape / image / line / table / elementGroup.
/// An element where every known union member is nil is an out-of-profile element
/// (e.g. video, wordArt) — first-class for renderers as `kind == .unknown`.
public struct PageElement: Codable, Equatable, Sendable {
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
    public var video: Video?
    public var wordArt: WordArt?
    public var sheetsChart: SheetsChart?
    public var speakerSpotlight: SpeakerSpotlight?

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
        elementGroup: Group? = nil,
        video: Video? = nil,
        wordArt: WordArt? = nil,
        sheetsChart: SheetsChart? = nil,
        speakerSpotlight: SpeakerSpotlight? = nil
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
        self.video = video
        self.wordArt = wordArt
        self.sheetsChart = sheetsChart
        self.speakerSpotlight = speakerSpotlight
    }

    public enum Kind: Equatable, Sendable {
        case shape(Shape)
        case image(Image)
        case line(Line)
        case table(Table)
        case elementGroup(Group)
        case video(Video)
        case wordArt(WordArt)
        case sheetsChart(SheetsChart)
        case speakerSpotlight(SpeakerSpotlight)
        /// A union member outside this profile (none of the spec's element kinds present).
        case unknown
    }

    public var kind: Kind {
        if let shape { return .shape(shape) }
        if let image { return .image(image) }
        if let line { return .line(line) }
        if let table { return .table(table) }
        if let elementGroup { return .elementGroup(elementGroup) }
        if let video { return .video(video) }
        if let wordArt { return .wordArt(wordArt) }
        if let sheetsChart { return .sheetsChart(sheetsChart) }
        if let speakerSpotlight { return .speakerSpotlight(speakerSpotlight) }
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

public struct Placeholder: Codable, Equatable, Sendable {
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

public struct Autofit: Codable, Equatable, Sendable {
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

public struct ShapeBackgroundFill: Codable, Equatable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct ContentAlignment: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "CONTENT_ALIGNMENT_UNSPECIFIED")
    public static let unsupported = Self(rawValue: "CONTENT_ALIGNMENT_UNSUPPORTED")
    public static let top = Self(rawValue: "TOP")
    public static let middle = Self(rawValue: "MIDDLE")
    public static let bottom = Self(rawValue: "BOTTOM")

    public static var knownValues: [Self] { [.unspecified, .unsupported, .top, .middle, .bottom] }
}

public struct Outline: Codable, Equatable, Sendable {
    public var outlineFill: OutlineFill?
    public var weight: Dimension?
    public var dashStyle: DashStyle?
    public var propertyState: PropertyState?

    public init(
        outlineFill: OutlineFill? = nil,
        weight: Dimension? = nil,
        dashStyle: DashStyle? = nil,
        propertyState: PropertyState? = nil
    ) {
        self.outlineFill = outlineFill
        self.weight = weight
        self.dashStyle = dashStyle
        self.propertyState = propertyState
    }
}

public struct OutlineFill: Codable, Equatable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct ShapeProperties: Codable, Equatable, Sendable {
    public var shapeBackgroundFill: ShapeBackgroundFill?
    public var outline: Outline?
    public var shadow: Shadow?
    public var link: Link?
    public var contentAlignment: ContentAlignment?
    public var autofit: Autofit?

    public init(
        shapeBackgroundFill: ShapeBackgroundFill? = nil,
        outline: Outline? = nil,
        shadow: Shadow? = nil,
        link: Link? = nil,
        contentAlignment: ContentAlignment? = nil,
        autofit: Autofit? = nil
    ) {
        self.shapeBackgroundFill = shapeBackgroundFill
        self.outline = outline
        self.shadow = shadow
        self.link = link
        self.contentAlignment = contentAlignment
        self.autofit = autofit
    }
}

public struct Shape: Codable, Equatable, Sendable {
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

public struct ImageProperties: Codable, Equatable, Sendable {
    public var cropProperties: CropProperties?
    public var transparency: Double?
    public var brightness: Double?
    public var contrast: Double?
    public var recolor: Recolor?
    public var outline: Outline?
    public var shadow: Shadow?
    public var link: Link?

    public init(
        cropProperties: CropProperties? = nil,
        transparency: Double? = nil,
        brightness: Double? = nil,
        contrast: Double? = nil,
        recolor: Recolor? = nil,
        outline: Outline? = nil,
        shadow: Shadow? = nil,
        link: Link? = nil
    ) {
        self.cropProperties = cropProperties
        self.transparency = transparency
        self.brightness = brightness
        self.contrast = contrast
        self.recolor = recolor
        self.outline = outline
        self.shadow = shadow
        self.link = link
    }
}

public struct Image: Codable, Equatable, Sendable {
    public var contentUrl: String?
    public var sourceUrl: String?
    public var imageProperties: ImageProperties?
    public var placeholder: Placeholder?

    public init(
        contentUrl: String? = nil,
        sourceUrl: String? = nil,
        imageProperties: ImageProperties? = nil,
        placeholder: Placeholder? = nil
    ) {
        self.contentUrl = contentUrl
        self.sourceUrl = sourceUrl
        self.imageProperties = imageProperties
        self.placeholder = placeholder
    }
}

// MARK: - Profile union members previously stubbed as `.unknown`, now first-class.

public struct VideoProperties: Codable, Equatable, Sendable {
    public var outline: Outline?
    public var autoPlay: Bool?
    public var start: Int?
    public var end: Int?
    public var mute: Bool?

    public init(
        outline: Outline? = nil,
        autoPlay: Bool? = nil,
        start: Int? = nil,
        end: Int? = nil,
        mute: Bool? = nil
    ) {
        self.outline = outline
        self.autoPlay = autoPlay
        self.start = start
        self.end = end
        self.mute = mute
    }
}

public struct Video: Codable, Equatable, Sendable {
    public var url: String?
    public var source: String?
    public var id: String?
    public var videoProperties: VideoProperties?

    public init(url: String? = nil, source: String? = nil, id: String? = nil, videoProperties: VideoProperties? = nil) {
        self.url = url
        self.source = source
        self.id = id
        self.videoProperties = videoProperties
    }
}

public struct WordArt: Codable, Equatable, Sendable {
    public var renderedText: String?

    public init(renderedText: String? = nil) {
        self.renderedText = renderedText
    }
}

public struct SheetsChartProperties: Codable, Equatable, Sendable {
    public var chartImageProperties: ImageProperties?

    public init(chartImageProperties: ImageProperties? = nil) {
        self.chartImageProperties = chartImageProperties
    }
}

public struct SheetsChart: Codable, Equatable, Sendable {
    public var spreadsheetId: String?
    public var chartId: Int?
    public var contentUrl: String?
    public var sheetsChartProperties: SheetsChartProperties?

    public init(
        spreadsheetId: String? = nil,
        chartId: Int? = nil,
        contentUrl: String? = nil,
        sheetsChartProperties: SheetsChartProperties? = nil
    ) {
        self.spreadsheetId = spreadsheetId
        self.chartId = chartId
        self.contentUrl = contentUrl
        self.sheetsChartProperties = sheetsChartProperties
    }
}

public struct SpeakerSpotlightProperties: Codable, Equatable, Sendable {
    public var outline: Outline?
    public var shadow: Shadow?

    public init(outline: Outline? = nil, shadow: Shadow? = nil) {
        self.outline = outline
        self.shadow = shadow
    }
}

public struct SpeakerSpotlight: Codable, Equatable, Sendable {
    public var speakerSpotlightProperties: SpeakerSpotlightProperties?

    public init(speakerSpotlightProperties: SpeakerSpotlightProperties? = nil) {
        self.speakerSpotlightProperties = speakerSpotlightProperties
    }
}

public struct ArrowStyle: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "ARROW_STYLE_UNSPECIFIED")
    public static let none = Self(rawValue: "NONE")
    public static let stealthArrow = Self(rawValue: "STEALTH_ARROW")
    public static let fillArrow = Self(rawValue: "FILL_ARROW")
    public static let fillCircle = Self(rawValue: "FILL_CIRCLE")
    public static let fillSquare = Self(rawValue: "FILL_SQUARE")
    public static let fillDiamond = Self(rawValue: "FILL_DIAMOND")
    public static let openArrow = Self(rawValue: "OPEN_ARROW")
    public static let openCircle = Self(rawValue: "OPEN_CIRCLE")
    public static let openSquare = Self(rawValue: "OPEN_SQUARE")
    public static let openDiamond = Self(rawValue: "OPEN_DIAMOND")

    public static var knownValues: [Self] {
        [.unspecified, .none, .stealthArrow, .fillArrow, .fillCircle, .fillSquare,
         .fillDiamond, .openArrow, .openCircle, .openSquare, .openDiamond]
    }
}

public struct LineProperties: Codable, Equatable, Sendable {
    public var lineFill: LineFill?
    public var weight: Dimension?
    public var dashStyle: DashStyle?
    public var startArrow: ArrowStyle?
    public var endArrow: ArrowStyle?
    public var link: Link?

    public init(
        lineFill: LineFill? = nil,
        weight: Dimension? = nil,
        dashStyle: DashStyle? = nil,
        startArrow: ArrowStyle? = nil,
        endArrow: ArrowStyle? = nil,
        link: Link? = nil
    ) {
        self.lineFill = lineFill
        self.weight = weight
        self.dashStyle = dashStyle
        self.startArrow = startArrow
        self.endArrow = endArrow
        self.link = link
    }
}

public struct LineFill: Codable, Equatable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct Line: Codable, Equatable, Sendable {
    public var lineProperties: LineProperties?

    public init(lineProperties: LineProperties? = nil) {
        self.lineProperties = lineProperties
    }
}

public struct TableCellLocation: Codable, Equatable, Sendable {
    public var rowIndex: Int?
    public var columnIndex: Int?

    public init(rowIndex: Int? = nil, columnIndex: Int? = nil) {
        self.rowIndex = rowIndex
        self.columnIndex = columnIndex
    }
}

public struct TableCellBackgroundFill: Codable, Equatable, Sendable {
    public var solidFill: SolidFill?

    public init(solidFill: SolidFill? = nil) {
        self.solidFill = solidFill
    }
}

public struct TableCellProperties: Codable, Equatable, Sendable {
    public var tableCellBackgroundFill: TableCellBackgroundFill?
    public var contentAlignment: ContentAlignment?

    public init(tableCellBackgroundFill: TableCellBackgroundFill? = nil, contentAlignment: ContentAlignment? = nil) {
        self.tableCellBackgroundFill = tableCellBackgroundFill
        self.contentAlignment = contentAlignment
    }
}

public struct TableCell: Codable, Equatable, Sendable {
    public var location: TableCellLocation?
    public var rowSpan: Int?
    public var columnSpan: Int?
    public var text: TextContent?
    public var tableCellProperties: TableCellProperties?

    public init(
        location: TableCellLocation? = nil,
        rowSpan: Int? = nil,
        columnSpan: Int? = nil,
        text: TextContent? = nil,
        tableCellProperties: TableCellProperties? = nil
    ) {
        self.location = location
        self.rowSpan = rowSpan
        self.columnSpan = columnSpan
        self.text = text
        self.tableCellProperties = tableCellProperties
    }
}

public struct TableRow: Codable, Equatable, Sendable {
    public var rowHeight: Dimension?
    public var tableCells: [TableCell]?

    public init(rowHeight: Dimension? = nil, tableCells: [TableCell]? = nil) {
        self.rowHeight = rowHeight
        self.tableCells = tableCells
    }
}

public struct TableColumnProperties: Codable, Equatable, Sendable {
    public var columnWidth: Dimension?

    public init(columnWidth: Dimension? = nil) {
        self.columnWidth = columnWidth
    }
}

public struct Table: Codable, Equatable, Sendable {
    public var rows: Int?
    public var columns: Int?
    public var tableRows: [TableRow]?
    public var tableColumns: [TableColumnProperties]?

    public init(rows: Int? = nil, columns: Int? = nil, tableRows: [TableRow]? = nil, tableColumns: [TableColumnProperties]? = nil) {
        self.rows = rows
        self.columns = columns
        self.tableRows = tableRows
        self.tableColumns = tableColumns
    }
}

public struct Group: Codable, Equatable, Sendable {
    public var children: [PageElement]?

    public init(children: [PageElement]? = nil) {
        self.children = children
    }
}
