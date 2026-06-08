// Generated from the Google Slides API discovery document (batchUpdate write model).
// Field-faithful Codable mirror; all properties optional for resilient decoding.
import GSlidesSchema
import StructuredDataCore

/// Escape hatch for free-form JSON values in a few request fields.
public typealias StructuredJSON = StructuredValue

public struct CreateLineRequestCategory: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let lineCategoryUnspecified = Self(rawValue: "LINE_CATEGORY_UNSPECIFIED")
    public static let straight = Self(rawValue: "STRAIGHT")
    public static let bent = Self(rawValue: "BENT")
    public static let curved = Self(rawValue: "CURVED")

    public static var knownValues: [Self] { [.lineCategoryUnspecified, .straight, .bent, .curved] }
}

public struct CreateLineRequestLineCategory: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let straight = Self(rawValue: "STRAIGHT")
    public static let bent = Self(rawValue: "BENT")
    public static let curved = Self(rawValue: "CURVED")

    public static var knownValues: [Self] { [.straight, .bent, .curved] }
}

public struct CreateParagraphBulletsRequestBulletPreset: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let bulletDiscCircleSquare = Self(rawValue: "BULLET_DISC_CIRCLE_SQUARE")
    public static let bulletDiamondxArrow3dSquare = Self(rawValue: "BULLET_DIAMONDX_ARROW3D_SQUARE")
    public static let bulletCheckbox = Self(rawValue: "BULLET_CHECKBOX")
    public static let bulletArrowDiamondDisc = Self(rawValue: "BULLET_ARROW_DIAMOND_DISC")
    public static let bulletStarCircleSquare = Self(rawValue: "BULLET_STAR_CIRCLE_SQUARE")
    public static let bulletArrow3dCircleSquare = Self(rawValue: "BULLET_ARROW3D_CIRCLE_SQUARE")
    public static let bulletLefttriangleDiamondDisc = Self(rawValue: "BULLET_LEFTTRIANGLE_DIAMOND_DISC")
    public static let bulletDiamondxHollowdiamondSquare = Self(rawValue: "BULLET_DIAMONDX_HOLLOWDIAMOND_SQUARE")
    public static let bulletDiamondCircleSquare = Self(rawValue: "BULLET_DIAMOND_CIRCLE_SQUARE")
    public static let numberedDigitAlphaRoman = Self(rawValue: "NUMBERED_DIGIT_ALPHA_ROMAN")
    public static let numberedDigitAlphaRomanParens = Self(rawValue: "NUMBERED_DIGIT_ALPHA_ROMAN_PARENS")
    public static let numberedDigitNested = Self(rawValue: "NUMBERED_DIGIT_NESTED")
    public static let numberedUpperalphaAlphaRoman = Self(rawValue: "NUMBERED_UPPERALPHA_ALPHA_ROMAN")
    public static let numberedUpperromanUpperalphaDigit = Self(rawValue: "NUMBERED_UPPERROMAN_UPPERALPHA_DIGIT")
    public static let numberedZerodigitAlphaRoman = Self(rawValue: "NUMBERED_ZERODIGIT_ALPHA_ROMAN")

    public static var knownValues: [Self] { [.bulletDiscCircleSquare, .bulletDiamondxArrow3dSquare, .bulletCheckbox, .bulletArrowDiamondDisc, .bulletStarCircleSquare, .bulletArrow3dCircleSquare, .bulletLefttriangleDiamondDisc, .bulletDiamondxHollowdiamondSquare, .bulletDiamondCircleSquare, .numberedDigitAlphaRoman, .numberedDigitAlphaRomanParens, .numberedDigitNested, .numberedUpperalphaAlphaRoman, .numberedUpperromanUpperalphaDigit, .numberedZerodigitAlphaRoman] }
}

public struct CreateShapeRequestShapeType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let typeUnspecified = Self(rawValue: "TYPE_UNSPECIFIED")
    public static let textBox = Self(rawValue: "TEXT_BOX")
    public static let rectangle = Self(rawValue: "RECTANGLE")
    public static let roundRectangle = Self(rawValue: "ROUND_RECTANGLE")
    public static let ellipse = Self(rawValue: "ELLIPSE")
    public static let arc = Self(rawValue: "ARC")
    public static let bentArrow = Self(rawValue: "BENT_ARROW")
    public static let bentUpArrow = Self(rawValue: "BENT_UP_ARROW")
    public static let bevel = Self(rawValue: "BEVEL")
    public static let blockArc = Self(rawValue: "BLOCK_ARC")
    public static let bracePair = Self(rawValue: "BRACE_PAIR")
    public static let bracketPair = Self(rawValue: "BRACKET_PAIR")
    public static let can = Self(rawValue: "CAN")
    public static let chevron = Self(rawValue: "CHEVRON")
    public static let chord = Self(rawValue: "CHORD")
    public static let cloud = Self(rawValue: "CLOUD")
    public static let corner = Self(rawValue: "CORNER")
    public static let cube = Self(rawValue: "CUBE")
    public static let curvedDownArrow = Self(rawValue: "CURVED_DOWN_ARROW")
    public static let curvedLeftArrow = Self(rawValue: "CURVED_LEFT_ARROW")
    public static let curvedRightArrow = Self(rawValue: "CURVED_RIGHT_ARROW")
    public static let curvedUpArrow = Self(rawValue: "CURVED_UP_ARROW")
    public static let decagon = Self(rawValue: "DECAGON")
    public static let diagonalStripe = Self(rawValue: "DIAGONAL_STRIPE")
    public static let diamond = Self(rawValue: "DIAMOND")
    public static let dodecagon = Self(rawValue: "DODECAGON")
    public static let donut = Self(rawValue: "DONUT")
    public static let doubleWave = Self(rawValue: "DOUBLE_WAVE")
    public static let downArrow = Self(rawValue: "DOWN_ARROW")
    public static let downArrowCallout = Self(rawValue: "DOWN_ARROW_CALLOUT")
    public static let foldedCorner = Self(rawValue: "FOLDED_CORNER")
    public static let frame = Self(rawValue: "FRAME")
    public static let halfFrame = Self(rawValue: "HALF_FRAME")
    public static let heart = Self(rawValue: "HEART")
    public static let heptagon = Self(rawValue: "HEPTAGON")
    public static let hexagon = Self(rawValue: "HEXAGON")
    public static let homePlate = Self(rawValue: "HOME_PLATE")
    public static let horizontalScroll = Self(rawValue: "HORIZONTAL_SCROLL")
    public static let irregularSeal1 = Self(rawValue: "IRREGULAR_SEAL_1")
    public static let irregularSeal2 = Self(rawValue: "IRREGULAR_SEAL_2")
    public static let leftArrow = Self(rawValue: "LEFT_ARROW")
    public static let leftArrowCallout = Self(rawValue: "LEFT_ARROW_CALLOUT")
    public static let leftBrace = Self(rawValue: "LEFT_BRACE")
    public static let leftBracket = Self(rawValue: "LEFT_BRACKET")
    public static let leftRightArrow = Self(rawValue: "LEFT_RIGHT_ARROW")
    public static let leftRightArrowCallout = Self(rawValue: "LEFT_RIGHT_ARROW_CALLOUT")
    public static let leftRightUpArrow = Self(rawValue: "LEFT_RIGHT_UP_ARROW")
    public static let leftUpArrow = Self(rawValue: "LEFT_UP_ARROW")
    public static let lightningBolt = Self(rawValue: "LIGHTNING_BOLT")
    public static let mathDivide = Self(rawValue: "MATH_DIVIDE")
    public static let mathEqual = Self(rawValue: "MATH_EQUAL")
    public static let mathMinus = Self(rawValue: "MATH_MINUS")
    public static let mathMultiply = Self(rawValue: "MATH_MULTIPLY")
    public static let mathNotEqual = Self(rawValue: "MATH_NOT_EQUAL")
    public static let mathPlus = Self(rawValue: "MATH_PLUS")
    public static let moon = Self(rawValue: "MOON")
    public static let noSmoking = Self(rawValue: "NO_SMOKING")
    public static let notchedRightArrow = Self(rawValue: "NOTCHED_RIGHT_ARROW")
    public static let octagon = Self(rawValue: "OCTAGON")
    public static let parallelogram = Self(rawValue: "PARALLELOGRAM")
    public static let pentagon = Self(rawValue: "PENTAGON")
    public static let pie = Self(rawValue: "PIE")
    public static let plaque = Self(rawValue: "PLAQUE")
    public static let plus = Self(rawValue: "PLUS")
    public static let quadArrow = Self(rawValue: "QUAD_ARROW")
    public static let quadArrowCallout = Self(rawValue: "QUAD_ARROW_CALLOUT")
    public static let ribbon = Self(rawValue: "RIBBON")
    public static let ribbon2 = Self(rawValue: "RIBBON_2")
    public static let rightArrow = Self(rawValue: "RIGHT_ARROW")
    public static let rightArrowCallout = Self(rawValue: "RIGHT_ARROW_CALLOUT")
    public static let rightBrace = Self(rawValue: "RIGHT_BRACE")
    public static let rightBracket = Self(rawValue: "RIGHT_BRACKET")
    public static let round1Rectangle = Self(rawValue: "ROUND_1_RECTANGLE")
    public static let round2DiagonalRectangle = Self(rawValue: "ROUND_2_DIAGONAL_RECTANGLE")
    public static let round2SameRectangle = Self(rawValue: "ROUND_2_SAME_RECTANGLE")
    public static let rightTriangle = Self(rawValue: "RIGHT_TRIANGLE")
    public static let smileyFace = Self(rawValue: "SMILEY_FACE")
    public static let snip1Rectangle = Self(rawValue: "SNIP_1_RECTANGLE")
    public static let snip2DiagonalRectangle = Self(rawValue: "SNIP_2_DIAGONAL_RECTANGLE")
    public static let snip2SameRectangle = Self(rawValue: "SNIP_2_SAME_RECTANGLE")
    public static let snipRoundRectangle = Self(rawValue: "SNIP_ROUND_RECTANGLE")
    public static let star10 = Self(rawValue: "STAR_10")
    public static let star12 = Self(rawValue: "STAR_12")
    public static let star16 = Self(rawValue: "STAR_16")
    public static let star24 = Self(rawValue: "STAR_24")
    public static let star32 = Self(rawValue: "STAR_32")
    public static let star4 = Self(rawValue: "STAR_4")
    public static let star5 = Self(rawValue: "STAR_5")
    public static let star6 = Self(rawValue: "STAR_6")
    public static let star7 = Self(rawValue: "STAR_7")
    public static let star8 = Self(rawValue: "STAR_8")
    public static let stripedRightArrow = Self(rawValue: "STRIPED_RIGHT_ARROW")
    public static let sun = Self(rawValue: "SUN")
    public static let trapezoid = Self(rawValue: "TRAPEZOID")
    public static let triangle = Self(rawValue: "TRIANGLE")
    public static let upArrow = Self(rawValue: "UP_ARROW")
    public static let upArrowCallout = Self(rawValue: "UP_ARROW_CALLOUT")
    public static let upDownArrow = Self(rawValue: "UP_DOWN_ARROW")
    public static let uturnArrow = Self(rawValue: "UTURN_ARROW")
    public static let verticalScroll = Self(rawValue: "VERTICAL_SCROLL")
    public static let wave = Self(rawValue: "WAVE")
    public static let wedgeEllipseCallout = Self(rawValue: "WEDGE_ELLIPSE_CALLOUT")
    public static let wedgeRectangleCallout = Self(rawValue: "WEDGE_RECTANGLE_CALLOUT")
    public static let wedgeRoundRectangleCallout = Self(rawValue: "WEDGE_ROUND_RECTANGLE_CALLOUT")
    public static let flowChartAlternateProcess = Self(rawValue: "FLOW_CHART_ALTERNATE_PROCESS")
    public static let flowChartCollate = Self(rawValue: "FLOW_CHART_COLLATE")
    public static let flowChartConnector = Self(rawValue: "FLOW_CHART_CONNECTOR")
    public static let flowChartDecision = Self(rawValue: "FLOW_CHART_DECISION")
    public static let flowChartDelay = Self(rawValue: "FLOW_CHART_DELAY")
    public static let flowChartDisplay = Self(rawValue: "FLOW_CHART_DISPLAY")
    public static let flowChartDocument = Self(rawValue: "FLOW_CHART_DOCUMENT")
    public static let flowChartExtract = Self(rawValue: "FLOW_CHART_EXTRACT")
    public static let flowChartInputOutput = Self(rawValue: "FLOW_CHART_INPUT_OUTPUT")
    public static let flowChartInternalStorage = Self(rawValue: "FLOW_CHART_INTERNAL_STORAGE")
    public static let flowChartMagneticDisk = Self(rawValue: "FLOW_CHART_MAGNETIC_DISK")
    public static let flowChartMagneticDrum = Self(rawValue: "FLOW_CHART_MAGNETIC_DRUM")
    public static let flowChartMagneticTape = Self(rawValue: "FLOW_CHART_MAGNETIC_TAPE")
    public static let flowChartManualInput = Self(rawValue: "FLOW_CHART_MANUAL_INPUT")
    public static let flowChartManualOperation = Self(rawValue: "FLOW_CHART_MANUAL_OPERATION")
    public static let flowChartMerge = Self(rawValue: "FLOW_CHART_MERGE")
    public static let flowChartMultidocument = Self(rawValue: "FLOW_CHART_MULTIDOCUMENT")
    public static let flowChartOfflineStorage = Self(rawValue: "FLOW_CHART_OFFLINE_STORAGE")
    public static let flowChartOffpageConnector = Self(rawValue: "FLOW_CHART_OFFPAGE_CONNECTOR")
    public static let flowChartOnlineStorage = Self(rawValue: "FLOW_CHART_ONLINE_STORAGE")
    public static let flowChartOr = Self(rawValue: "FLOW_CHART_OR")
    public static let flowChartPredefinedProcess = Self(rawValue: "FLOW_CHART_PREDEFINED_PROCESS")
    public static let flowChartPreparation = Self(rawValue: "FLOW_CHART_PREPARATION")
    public static let flowChartProcess = Self(rawValue: "FLOW_CHART_PROCESS")
    public static let flowChartPunchedCard = Self(rawValue: "FLOW_CHART_PUNCHED_CARD")
    public static let flowChartPunchedTape = Self(rawValue: "FLOW_CHART_PUNCHED_TAPE")
    public static let flowChartSort = Self(rawValue: "FLOW_CHART_SORT")
    public static let flowChartSummingJunction = Self(rawValue: "FLOW_CHART_SUMMING_JUNCTION")
    public static let flowChartTerminator = Self(rawValue: "FLOW_CHART_TERMINATOR")
    public static let arrowEast = Self(rawValue: "ARROW_EAST")
    public static let arrowNorthEast = Self(rawValue: "ARROW_NORTH_EAST")
    public static let arrowNorth = Self(rawValue: "ARROW_NORTH")
    public static let speech = Self(rawValue: "SPEECH")
    public static let starburst = Self(rawValue: "STARBURST")
    public static let teardrop = Self(rawValue: "TEARDROP")
    public static let ellipseRibbon = Self(rawValue: "ELLIPSE_RIBBON")
    public static let ellipseRibbon2 = Self(rawValue: "ELLIPSE_RIBBON_2")
    public static let cloudCallout = Self(rawValue: "CLOUD_CALLOUT")
    public static let custom = Self(rawValue: "CUSTOM")

    public static var knownValues: [Self] { [.typeUnspecified, .textBox, .rectangle, .roundRectangle, .ellipse, .arc, .bentArrow, .bentUpArrow, .bevel, .blockArc, .bracePair, .bracketPair, .can, .chevron, .chord, .cloud, .corner, .cube, .curvedDownArrow, .curvedLeftArrow, .curvedRightArrow, .curvedUpArrow, .decagon, .diagonalStripe, .diamond, .dodecagon, .donut, .doubleWave, .downArrow, .downArrowCallout, .foldedCorner, .frame, .halfFrame, .heart, .heptagon, .hexagon, .homePlate, .horizontalScroll, .irregularSeal1, .irregularSeal2, .leftArrow, .leftArrowCallout, .leftBrace, .leftBracket, .leftRightArrow, .leftRightArrowCallout, .leftRightUpArrow, .leftUpArrow, .lightningBolt, .mathDivide, .mathEqual, .mathMinus, .mathMultiply, .mathNotEqual, .mathPlus, .moon, .noSmoking, .notchedRightArrow, .octagon, .parallelogram, .pentagon, .pie, .plaque, .plus, .quadArrow, .quadArrowCallout, .ribbon, .ribbon2, .rightArrow, .rightArrowCallout, .rightBrace, .rightBracket, .round1Rectangle, .round2DiagonalRectangle, .round2SameRectangle, .rightTriangle, .smileyFace, .snip1Rectangle, .snip2DiagonalRectangle, .snip2SameRectangle, .snipRoundRectangle, .star10, .star12, .star16, .star24, .star32, .star4, .star5, .star6, .star7, .star8, .stripedRightArrow, .sun, .trapezoid, .triangle, .upArrow, .upArrowCallout, .upDownArrow, .uturnArrow, .verticalScroll, .wave, .wedgeEllipseCallout, .wedgeRectangleCallout, .wedgeRoundRectangleCallout, .flowChartAlternateProcess, .flowChartCollate, .flowChartConnector, .flowChartDecision, .flowChartDelay, .flowChartDisplay, .flowChartDocument, .flowChartExtract, .flowChartInputOutput, .flowChartInternalStorage, .flowChartMagneticDisk, .flowChartMagneticDrum, .flowChartMagneticTape, .flowChartManualInput, .flowChartManualOperation, .flowChartMerge, .flowChartMultidocument, .flowChartOfflineStorage, .flowChartOffpageConnector, .flowChartOnlineStorage, .flowChartOr, .flowChartPredefinedProcess, .flowChartPreparation, .flowChartProcess, .flowChartPunchedCard, .flowChartPunchedTape, .flowChartSort, .flowChartSummingJunction, .flowChartTerminator, .arrowEast, .arrowNorthEast, .arrowNorth, .speech, .starburst, .teardrop, .ellipseRibbon, .ellipseRibbon2, .cloudCallout, .custom] }
}

public struct CreateSheetsChartRequestLinkingMode: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let notLinkedImage = Self(rawValue: "NOT_LINKED_IMAGE")
    public static let linked = Self(rawValue: "LINKED")

    public static var knownValues: [Self] { [.notLinkedImage, .linked] }
}

public struct CreateVideoRequestSource: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let sourceUnspecified = Self(rawValue: "SOURCE_UNSPECIFIED")
    public static let youtube = Self(rawValue: "YOUTUBE")
    public static let drive = Self(rawValue: "DRIVE")

    public static var knownValues: [Self] { [.sourceUnspecified, .youtube, .drive] }
}

public struct RangeType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let rangeTypeUnspecified = Self(rawValue: "RANGE_TYPE_UNSPECIFIED")
    public static let fixedRange = Self(rawValue: "FIXED_RANGE")
    public static let fromStartIndex = Self(rawValue: "FROM_START_INDEX")
    public static let all = Self(rawValue: "ALL")

    public static var knownValues: [Self] { [.rangeTypeUnspecified, .fixedRange, .fromStartIndex, .all] }
}

public struct ReplaceAllShapesWithImageRequestImageReplaceMethod: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let imageReplaceMethodUnspecified = Self(rawValue: "IMAGE_REPLACE_METHOD_UNSPECIFIED")
    public static let centerInside = Self(rawValue: "CENTER_INSIDE")
    public static let centerCrop = Self(rawValue: "CENTER_CROP")

    public static var knownValues: [Self] { [.imageReplaceMethodUnspecified, .centerInside, .centerCrop] }
}

public struct ReplaceAllShapesWithImageRequestReplaceMethod: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let centerInside = Self(rawValue: "CENTER_INSIDE")
    public static let centerCrop = Self(rawValue: "CENTER_CROP")

    public static var knownValues: [Self] { [.centerInside, .centerCrop] }
}

public struct ReplaceAllShapesWithSheetsChartRequestLinkingMode: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let notLinkedImage = Self(rawValue: "NOT_LINKED_IMAGE")
    public static let linked = Self(rawValue: "LINKED")

    public static var knownValues: [Self] { [.notLinkedImage, .linked] }
}

public struct ReplaceImageRequestImageReplaceMethod: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let imageReplaceMethodUnspecified = Self(rawValue: "IMAGE_REPLACE_METHOD_UNSPECIFIED")
    public static let centerInside = Self(rawValue: "CENTER_INSIDE")
    public static let centerCrop = Self(rawValue: "CENTER_CROP")

    public static var knownValues: [Self] { [.imageReplaceMethodUnspecified, .centerInside, .centerCrop] }
}

public struct TableBorderPropertiesDashStyle: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let dashStyleUnspecified = Self(rawValue: "DASH_STYLE_UNSPECIFIED")
    public static let solid = Self(rawValue: "SOLID")
    public static let dot = Self(rawValue: "DOT")
    public static let dash = Self(rawValue: "DASH")
    public static let dashDot = Self(rawValue: "DASH_DOT")
    public static let longDash = Self(rawValue: "LONG_DASH")
    public static let longDashDot = Self(rawValue: "LONG_DASH_DOT")

    public static var knownValues: [Self] { [.dashStyleUnspecified, .solid, .dot, .dash, .dashDot, .longDash, .longDashDot] }
}

public struct TableCellBackgroundFillPropertyState: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let rendered = Self(rawValue: "RENDERED")
    public static let notRendered = Self(rawValue: "NOT_RENDERED")
    public static let inherit = Self(rawValue: "INHERIT")

    public static var knownValues: [Self] { [.rendered, .notRendered, .inherit] }
}

public struct TableCellPropertiesContentAlignment: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let contentAlignmentUnspecified = Self(rawValue: "CONTENT_ALIGNMENT_UNSPECIFIED")
    public static let contentAlignmentUnsupported = Self(rawValue: "CONTENT_ALIGNMENT_UNSUPPORTED")
    public static let top = Self(rawValue: "TOP")
    public static let middle = Self(rawValue: "MIDDLE")
    public static let bottom = Self(rawValue: "BOTTOM")

    public static var knownValues: [Self] { [.contentAlignmentUnspecified, .contentAlignmentUnsupported, .top, .middle, .bottom] }
}

public struct UpdateLineCategoryRequestLineCategory: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let lineCategoryUnspecified = Self(rawValue: "LINE_CATEGORY_UNSPECIFIED")
    public static let straight = Self(rawValue: "STRAIGHT")
    public static let bent = Self(rawValue: "BENT")
    public static let curved = Self(rawValue: "CURVED")

    public static var knownValues: [Self] { [.lineCategoryUnspecified, .straight, .bent, .curved] }
}

public struct UpdatePageElementTransformRequestApplyMode: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let applyModeUnspecified = Self(rawValue: "APPLY_MODE_UNSPECIFIED")
    public static let relative = Self(rawValue: "RELATIVE")
    public static let absolute = Self(rawValue: "ABSOLUTE")

    public static var knownValues: [Self] { [.applyModeUnspecified, .relative, .absolute] }
}

public struct UpdatePageElementsZOrderRequestOperation: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let zOrderOperationUnspecified = Self(rawValue: "Z_ORDER_OPERATION_UNSPECIFIED")
    public static let bringToFront = Self(rawValue: "BRING_TO_FRONT")
    public static let bringForward = Self(rawValue: "BRING_FORWARD")
    public static let sendBackward = Self(rawValue: "SEND_BACKWARD")
    public static let sendToBack = Self(rawValue: "SEND_TO_BACK")

    public static var knownValues: [Self] { [.zOrderOperationUnspecified, .bringToFront, .bringForward, .sendBackward, .sendToBack] }
}

public struct UpdateTableBorderPropertiesRequestBorderPosition: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let all = Self(rawValue: "ALL")
    public static let bottom = Self(rawValue: "BOTTOM")
    public static let inner = Self(rawValue: "INNER")
    public static let innerHorizontal = Self(rawValue: "INNER_HORIZONTAL")
    public static let innerVertical = Self(rawValue: "INNER_VERTICAL")
    public static let left = Self(rawValue: "LEFT")
    public static let outer = Self(rawValue: "OUTER")
    public static let right = Self(rawValue: "RIGHT")
    public static let top = Self(rawValue: "TOP")

    public static var knownValues: [Self] { [.all, .bottom, .inner, .innerHorizontal, .innerVertical, .left, .outer, .right, .top] }
}

public struct BatchUpdatePresentationRequest: Codable, Hashable, Sendable {
    public var requests: [Request]?
    public var writeControl: WriteControl?

    public init(
        requests: [Request]? = nil,
        writeControl: WriteControl? = nil
    ) {
        self.requests = requests
        self.writeControl = writeControl
    }
}

public struct Request: Codable, Hashable, Sendable {
    public var createSlide: CreateSlideRequest?
    public var createShape: CreateShapeRequest?
    public var createTable: CreateTableRequest?
    public var insertText: InsertTextRequest?
    public var insertTableRows: InsertTableRowsRequest?
    public var insertTableColumns: InsertTableColumnsRequest?
    public var deleteTableRow: DeleteTableRowRequest?
    public var deleteTableColumn: DeleteTableColumnRequest?
    public var replaceAllText: ReplaceAllTextRequest?
    public var deleteObject: DeleteObjectRequest?
    public var updatePageElementTransform: UpdatePageElementTransformRequest?
    public var updateSlidesPosition: UpdateSlidesPositionRequest?
    public var deleteText: DeleteTextRequest?
    public var createImage: CreateImageRequest?
    public var createVideo: CreateVideoRequest?
    public var createSheetsChart: CreateSheetsChartRequest?
    public var createLine: CreateLineRequest?
    public var refreshSheetsChart: RefreshSheetsChartRequest?
    public var updateShapeProperties: UpdateShapePropertiesRequest?
    public var updateImageProperties: UpdateImagePropertiesRequest?
    public var updateVideoProperties: UpdateVideoPropertiesRequest?
    public var updatePageProperties: UpdatePagePropertiesRequest?
    public var updateTableCellProperties: UpdateTableCellPropertiesRequest?
    public var updateLineProperties: UpdateLinePropertiesRequest?
    public var createParagraphBullets: CreateParagraphBulletsRequest?
    public var replaceAllShapesWithImage: ReplaceAllShapesWithImageRequest?
    public var duplicateObject: DuplicateObjectRequest?
    public var updateTextStyle: UpdateTextStyleRequest?
    public var replaceAllShapesWithSheetsChart: ReplaceAllShapesWithSheetsChartRequest?
    public var deleteParagraphBullets: DeleteParagraphBulletsRequest?
    public var updateParagraphStyle: UpdateParagraphStyleRequest?
    public var updateTableBorderProperties: UpdateTableBorderPropertiesRequest?
    public var updateTableColumnProperties: UpdateTableColumnPropertiesRequest?
    public var updateTableRowProperties: UpdateTableRowPropertiesRequest?
    public var mergeTableCells: MergeTableCellsRequest?
    public var unmergeTableCells: UnmergeTableCellsRequest?
    public var groupObjects: GroupObjectsRequest?
    public var ungroupObjects: UngroupObjectsRequest?
    public var updatePageElementAltText: UpdatePageElementAltTextRequest?
    public var replaceImage: ReplaceImageRequest?
    public var updateSlideProperties: UpdateSlidePropertiesRequest?
    public var updatePageElementsZOrder: UpdatePageElementsZOrderRequest?
    public var updateLineCategory: UpdateLineCategoryRequest?
    public var rerouteLine: RerouteLineRequest?

    public init(
        createSlide: CreateSlideRequest? = nil,
        createShape: CreateShapeRequest? = nil,
        createTable: CreateTableRequest? = nil,
        insertText: InsertTextRequest? = nil,
        insertTableRows: InsertTableRowsRequest? = nil,
        insertTableColumns: InsertTableColumnsRequest? = nil,
        deleteTableRow: DeleteTableRowRequest? = nil,
        deleteTableColumn: DeleteTableColumnRequest? = nil,
        replaceAllText: ReplaceAllTextRequest? = nil,
        deleteObject: DeleteObjectRequest? = nil,
        updatePageElementTransform: UpdatePageElementTransformRequest? = nil,
        updateSlidesPosition: UpdateSlidesPositionRequest? = nil,
        deleteText: DeleteTextRequest? = nil,
        createImage: CreateImageRequest? = nil,
        createVideo: CreateVideoRequest? = nil,
        createSheetsChart: CreateSheetsChartRequest? = nil,
        createLine: CreateLineRequest? = nil,
        refreshSheetsChart: RefreshSheetsChartRequest? = nil,
        updateShapeProperties: UpdateShapePropertiesRequest? = nil,
        updateImageProperties: UpdateImagePropertiesRequest? = nil,
        updateVideoProperties: UpdateVideoPropertiesRequest? = nil,
        updatePageProperties: UpdatePagePropertiesRequest? = nil,
        updateTableCellProperties: UpdateTableCellPropertiesRequest? = nil,
        updateLineProperties: UpdateLinePropertiesRequest? = nil,
        createParagraphBullets: CreateParagraphBulletsRequest? = nil,
        replaceAllShapesWithImage: ReplaceAllShapesWithImageRequest? = nil,
        duplicateObject: DuplicateObjectRequest? = nil,
        updateTextStyle: UpdateTextStyleRequest? = nil,
        replaceAllShapesWithSheetsChart: ReplaceAllShapesWithSheetsChartRequest? = nil,
        deleteParagraphBullets: DeleteParagraphBulletsRequest? = nil,
        updateParagraphStyle: UpdateParagraphStyleRequest? = nil,
        updateTableBorderProperties: UpdateTableBorderPropertiesRequest? = nil,
        updateTableColumnProperties: UpdateTableColumnPropertiesRequest? = nil,
        updateTableRowProperties: UpdateTableRowPropertiesRequest? = nil,
        mergeTableCells: MergeTableCellsRequest? = nil,
        unmergeTableCells: UnmergeTableCellsRequest? = nil,
        groupObjects: GroupObjectsRequest? = nil,
        ungroupObjects: UngroupObjectsRequest? = nil,
        updatePageElementAltText: UpdatePageElementAltTextRequest? = nil,
        replaceImage: ReplaceImageRequest? = nil,
        updateSlideProperties: UpdateSlidePropertiesRequest? = nil,
        updatePageElementsZOrder: UpdatePageElementsZOrderRequest? = nil,
        updateLineCategory: UpdateLineCategoryRequest? = nil,
        rerouteLine: RerouteLineRequest? = nil
    ) {
        self.createSlide = createSlide
        self.createShape = createShape
        self.createTable = createTable
        self.insertText = insertText
        self.insertTableRows = insertTableRows
        self.insertTableColumns = insertTableColumns
        self.deleteTableRow = deleteTableRow
        self.deleteTableColumn = deleteTableColumn
        self.replaceAllText = replaceAllText
        self.deleteObject = deleteObject
        self.updatePageElementTransform = updatePageElementTransform
        self.updateSlidesPosition = updateSlidesPosition
        self.deleteText = deleteText
        self.createImage = createImage
        self.createVideo = createVideo
        self.createSheetsChart = createSheetsChart
        self.createLine = createLine
        self.refreshSheetsChart = refreshSheetsChart
        self.updateShapeProperties = updateShapeProperties
        self.updateImageProperties = updateImageProperties
        self.updateVideoProperties = updateVideoProperties
        self.updatePageProperties = updatePageProperties
        self.updateTableCellProperties = updateTableCellProperties
        self.updateLineProperties = updateLineProperties
        self.createParagraphBullets = createParagraphBullets
        self.replaceAllShapesWithImage = replaceAllShapesWithImage
        self.duplicateObject = duplicateObject
        self.updateTextStyle = updateTextStyle
        self.replaceAllShapesWithSheetsChart = replaceAllShapesWithSheetsChart
        self.deleteParagraphBullets = deleteParagraphBullets
        self.updateParagraphStyle = updateParagraphStyle
        self.updateTableBorderProperties = updateTableBorderProperties
        self.updateTableColumnProperties = updateTableColumnProperties
        self.updateTableRowProperties = updateTableRowProperties
        self.mergeTableCells = mergeTableCells
        self.unmergeTableCells = unmergeTableCells
        self.groupObjects = groupObjects
        self.ungroupObjects = ungroupObjects
        self.updatePageElementAltText = updatePageElementAltText
        self.replaceImage = replaceImage
        self.updateSlideProperties = updateSlideProperties
        self.updatePageElementsZOrder = updatePageElementsZOrder
        self.updateLineCategory = updateLineCategory
        self.rerouteLine = rerouteLine
    }
}

public struct CreateSlideRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var insertionIndex: Int?
    public var slideLayoutReference: LayoutReference?
    public var placeholderIdMappings: [LayoutPlaceholderIdMapping]?

    public init(
        objectId: String? = nil,
        insertionIndex: Int? = nil,
        slideLayoutReference: LayoutReference? = nil,
        placeholderIdMappings: [LayoutPlaceholderIdMapping]? = nil
    ) {
        self.objectId = objectId
        self.insertionIndex = insertionIndex
        self.slideLayoutReference = slideLayoutReference
        self.placeholderIdMappings = placeholderIdMappings
    }
}

public struct CreateShapeRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var shapeType: CreateShapeRequestShapeType?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        shapeType: CreateShapeRequestShapeType? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.shapeType = shapeType
    }
}

public struct CreateTableRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var rows: Int?
    public var columns: Int?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        rows: Int? = nil,
        columns: Int? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.rows = rows
        self.columns = columns
    }
}

public struct InsertTextRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var text: String?
    public var insertionIndex: Int?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        text: String? = nil,
        insertionIndex: Int? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.text = text
        self.insertionIndex = insertionIndex
    }
}

public struct InsertTableRowsRequest: Codable, Hashable, Sendable {
    public var tableObjectId: String?
    public var cellLocation: TableCellLocation?
    public var insertBelow: Bool?
    public var number: Int?

    public init(
        tableObjectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        insertBelow: Bool? = nil,
        number: Int? = nil
    ) {
        self.tableObjectId = tableObjectId
        self.cellLocation = cellLocation
        self.insertBelow = insertBelow
        self.number = number
    }
}

public struct InsertTableColumnsRequest: Codable, Hashable, Sendable {
    public var tableObjectId: String?
    public var cellLocation: TableCellLocation?
    public var insertRight: Bool?
    public var number: Int?

    public init(
        tableObjectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        insertRight: Bool? = nil,
        number: Int? = nil
    ) {
        self.tableObjectId = tableObjectId
        self.cellLocation = cellLocation
        self.insertRight = insertRight
        self.number = number
    }
}

public struct DeleteTableRowRequest: Codable, Hashable, Sendable {
    public var tableObjectId: String?
    public var cellLocation: TableCellLocation?

    public init(
        tableObjectId: String? = nil,
        cellLocation: TableCellLocation? = nil
    ) {
        self.tableObjectId = tableObjectId
        self.cellLocation = cellLocation
    }
}

public struct DeleteTableColumnRequest: Codable, Hashable, Sendable {
    public var tableObjectId: String?
    public var cellLocation: TableCellLocation?

    public init(
        tableObjectId: String? = nil,
        cellLocation: TableCellLocation? = nil
    ) {
        self.tableObjectId = tableObjectId
        self.cellLocation = cellLocation
    }
}

public struct ReplaceAllTextRequest: Codable, Hashable, Sendable {
    public var replaceText: String?
    public var pageObjectIds: [String]?
    public var containsText: SubstringMatchCriteria?

    public init(
        replaceText: String? = nil,
        pageObjectIds: [String]? = nil,
        containsText: SubstringMatchCriteria? = nil
    ) {
        self.replaceText = replaceText
        self.pageObjectIds = pageObjectIds
        self.containsText = containsText
    }
}

public struct DeleteObjectRequest: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct UpdatePageElementTransformRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var transform: AffineTransform?
    public var applyMode: UpdatePageElementTransformRequestApplyMode?

    public init(
        objectId: String? = nil,
        transform: AffineTransform? = nil,
        applyMode: UpdatePageElementTransformRequestApplyMode? = nil
    ) {
        self.objectId = objectId
        self.transform = transform
        self.applyMode = applyMode
    }
}

public struct UpdateSlidesPositionRequest: Codable, Hashable, Sendable {
    public var slideObjectIds: [String]?
    public var insertionIndex: Int?

    public init(
        slideObjectIds: [String]? = nil,
        insertionIndex: Int? = nil
    ) {
        self.slideObjectIds = slideObjectIds
        self.insertionIndex = insertionIndex
    }
}

public struct DeleteTextRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var textRange: Range?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        textRange: Range? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.textRange = textRange
    }
}

public struct CreateImageRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var url: String?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        url: String? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.url = url
    }
}

public struct CreateVideoRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var source: CreateVideoRequestSource?
    public var id: String?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        source: CreateVideoRequestSource? = nil,
        id: String? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.source = source
        self.id = id
    }
}

public struct CreateSheetsChartRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var spreadsheetId: String?
    public var chartId: Int?
    public var linkingMode: CreateSheetsChartRequestLinkingMode?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        spreadsheetId: String? = nil,
        chartId: Int? = nil,
        linkingMode: CreateSheetsChartRequestLinkingMode? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.spreadsheetId = spreadsheetId
        self.chartId = chartId
        self.linkingMode = linkingMode
    }
}

public struct CreateLineRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var elementProperties: PageElementProperties?
    public var lineCategory: CreateLineRequestLineCategory?
    public var category: CreateLineRequestCategory?

    public init(
        objectId: String? = nil,
        elementProperties: PageElementProperties? = nil,
        lineCategory: CreateLineRequestLineCategory? = nil,
        category: CreateLineRequestCategory? = nil
    ) {
        self.objectId = objectId
        self.elementProperties = elementProperties
        self.lineCategory = lineCategory
        self.category = category
    }
}

public struct RefreshSheetsChartRequest: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct UpdateShapePropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var shapeProperties: ShapeProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        shapeProperties: ShapeProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.shapeProperties = shapeProperties
        self.fields = fields
    }
}

public struct UpdateImagePropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var imageProperties: ImageProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        imageProperties: ImageProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.imageProperties = imageProperties
        self.fields = fields
    }
}

public struct UpdateVideoPropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var videoProperties: VideoProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        videoProperties: VideoProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.videoProperties = videoProperties
        self.fields = fields
    }
}

public struct UpdatePagePropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var pageProperties: PageProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        pageProperties: PageProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.pageProperties = pageProperties
        self.fields = fields
    }
}

public struct UpdateTableCellPropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var tableRange: TableRange?
    public var tableCellProperties: TableCellProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        tableRange: TableRange? = nil,
        tableCellProperties: TableCellProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.tableRange = tableRange
        self.tableCellProperties = tableCellProperties
        self.fields = fields
    }
}

public struct UpdateLinePropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var lineProperties: LineProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        lineProperties: LineProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.lineProperties = lineProperties
        self.fields = fields
    }
}

public struct CreateParagraphBulletsRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var textRange: Range?
    public var bulletPreset: CreateParagraphBulletsRequestBulletPreset?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        textRange: Range? = nil,
        bulletPreset: CreateParagraphBulletsRequestBulletPreset? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.textRange = textRange
        self.bulletPreset = bulletPreset
    }
}

public struct ReplaceAllShapesWithImageRequest: Codable, Hashable, Sendable {
    public var containsText: SubstringMatchCriteria?
    public var imageUrl: String?
    public var replaceMethod: ReplaceAllShapesWithImageRequestReplaceMethod?
    public var imageReplaceMethod: ReplaceAllShapesWithImageRequestImageReplaceMethod?
    public var pageObjectIds: [String]?

    public init(
        containsText: SubstringMatchCriteria? = nil,
        imageUrl: String? = nil,
        replaceMethod: ReplaceAllShapesWithImageRequestReplaceMethod? = nil,
        imageReplaceMethod: ReplaceAllShapesWithImageRequestImageReplaceMethod? = nil,
        pageObjectIds: [String]? = nil
    ) {
        self.containsText = containsText
        self.imageUrl = imageUrl
        self.replaceMethod = replaceMethod
        self.imageReplaceMethod = imageReplaceMethod
        self.pageObjectIds = pageObjectIds
    }
}

public struct DuplicateObjectRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var objectIds: [String: String]?

    public init(
        objectId: String? = nil,
        objectIds: [String: String]? = nil
    ) {
        self.objectId = objectId
        self.objectIds = objectIds
    }
}

public struct UpdateTextStyleRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var style: TextStyle?
    public var textRange: Range?
    public var fields: String?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        style: TextStyle? = nil,
        textRange: Range? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.style = style
        self.textRange = textRange
        self.fields = fields
    }
}

public struct ReplaceAllShapesWithSheetsChartRequest: Codable, Hashable, Sendable {
    public var containsText: SubstringMatchCriteria?
    public var spreadsheetId: String?
    public var chartId: Int?
    public var linkingMode: ReplaceAllShapesWithSheetsChartRequestLinkingMode?
    public var pageObjectIds: [String]?

    public init(
        containsText: SubstringMatchCriteria? = nil,
        spreadsheetId: String? = nil,
        chartId: Int? = nil,
        linkingMode: ReplaceAllShapesWithSheetsChartRequestLinkingMode? = nil,
        pageObjectIds: [String]? = nil
    ) {
        self.containsText = containsText
        self.spreadsheetId = spreadsheetId
        self.chartId = chartId
        self.linkingMode = linkingMode
        self.pageObjectIds = pageObjectIds
    }
}

public struct DeleteParagraphBulletsRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var textRange: Range?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        textRange: Range? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.textRange = textRange
    }
}

public struct UpdateParagraphStyleRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var cellLocation: TableCellLocation?
    public var style: ParagraphStyle?
    public var textRange: Range?
    public var fields: String?

    public init(
        objectId: String? = nil,
        cellLocation: TableCellLocation? = nil,
        style: ParagraphStyle? = nil,
        textRange: Range? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.cellLocation = cellLocation
        self.style = style
        self.textRange = textRange
        self.fields = fields
    }
}

public struct UpdateTableBorderPropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var tableRange: TableRange?
    public var borderPosition: UpdateTableBorderPropertiesRequestBorderPosition?
    public var tableBorderProperties: TableBorderProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        tableRange: TableRange? = nil,
        borderPosition: UpdateTableBorderPropertiesRequestBorderPosition? = nil,
        tableBorderProperties: TableBorderProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.tableRange = tableRange
        self.borderPosition = borderPosition
        self.tableBorderProperties = tableBorderProperties
        self.fields = fields
    }
}

public struct UpdateTableColumnPropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var columnIndices: [Int]?
    public var tableColumnProperties: TableColumnProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        columnIndices: [Int]? = nil,
        tableColumnProperties: TableColumnProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.columnIndices = columnIndices
        self.tableColumnProperties = tableColumnProperties
        self.fields = fields
    }
}

public struct UpdateTableRowPropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var rowIndices: [Int]?
    public var tableRowProperties: TableRowProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        rowIndices: [Int]? = nil,
        tableRowProperties: TableRowProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.rowIndices = rowIndices
        self.tableRowProperties = tableRowProperties
        self.fields = fields
    }
}

public struct MergeTableCellsRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var tableRange: TableRange?

    public init(
        objectId: String? = nil,
        tableRange: TableRange? = nil
    ) {
        self.objectId = objectId
        self.tableRange = tableRange
    }
}

public struct UnmergeTableCellsRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var tableRange: TableRange?

    public init(
        objectId: String? = nil,
        tableRange: TableRange? = nil
    ) {
        self.objectId = objectId
        self.tableRange = tableRange
    }
}

public struct GroupObjectsRequest: Codable, Hashable, Sendable {
    public var groupObjectId: String?
    public var childrenObjectIds: [String]?

    public init(
        groupObjectId: String? = nil,
        childrenObjectIds: [String]? = nil
    ) {
        self.groupObjectId = groupObjectId
        self.childrenObjectIds = childrenObjectIds
    }
}

public struct UngroupObjectsRequest: Codable, Hashable, Sendable {
    public var objectIds: [String]?

    public init(
        objectIds: [String]? = nil
    ) {
        self.objectIds = objectIds
    }
}

public struct UpdatePageElementAltTextRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var title: String?
    public var description: String?

    public init(
        objectId: String? = nil,
        title: String? = nil,
        description: String? = nil
    ) {
        self.objectId = objectId
        self.title = title
        self.description = description
    }
}

public struct ReplaceImageRequest: Codable, Hashable, Sendable {
    public var imageObjectId: String?
    public var url: String?
    public var imageReplaceMethod: ReplaceImageRequestImageReplaceMethod?

    public init(
        imageObjectId: String? = nil,
        url: String? = nil,
        imageReplaceMethod: ReplaceImageRequestImageReplaceMethod? = nil
    ) {
        self.imageObjectId = imageObjectId
        self.url = url
        self.imageReplaceMethod = imageReplaceMethod
    }
}

public struct UpdateSlidePropertiesRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var slideProperties: SlideProperties?
    public var fields: String?

    public init(
        objectId: String? = nil,
        slideProperties: SlideProperties? = nil,
        fields: String? = nil
    ) {
        self.objectId = objectId
        self.slideProperties = slideProperties
        self.fields = fields
    }
}

public struct UpdatePageElementsZOrderRequest: Codable, Hashable, Sendable {
    public var pageElementObjectIds: [String]?
    public var operation: UpdatePageElementsZOrderRequestOperation?

    public init(
        pageElementObjectIds: [String]? = nil,
        operation: UpdatePageElementsZOrderRequestOperation? = nil
    ) {
        self.pageElementObjectIds = pageElementObjectIds
        self.operation = operation
    }
}

public struct UpdateLineCategoryRequest: Codable, Hashable, Sendable {
    public var objectId: String?
    public var lineCategory: UpdateLineCategoryRequestLineCategory?

    public init(
        objectId: String? = nil,
        lineCategory: UpdateLineCategoryRequestLineCategory? = nil
    ) {
        self.objectId = objectId
        self.lineCategory = lineCategory
    }
}

public struct RerouteLineRequest: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct BatchUpdatePresentationResponse: Codable, Hashable, Sendable {
    public var presentationId: String?
    public var replies: [Response]?
    public var writeControl: WriteControl?

    public init(
        presentationId: String? = nil,
        replies: [Response]? = nil,
        writeControl: WriteControl? = nil
    ) {
        self.presentationId = presentationId
        self.replies = replies
        self.writeControl = writeControl
    }
}

public struct Response: Codable, Hashable, Sendable {
    public var createSlide: CreateSlideResponse?
    public var createShape: CreateShapeResponse?
    public var createTable: CreateTableResponse?
    public var replaceAllText: ReplaceAllTextResponse?
    public var createImage: CreateImageResponse?
    public var createVideo: CreateVideoResponse?
    public var createSheetsChart: CreateSheetsChartResponse?
    public var createLine: CreateLineResponse?
    public var replaceAllShapesWithImage: ReplaceAllShapesWithImageResponse?
    public var duplicateObject: DuplicateObjectResponse?
    public var replaceAllShapesWithSheetsChart: ReplaceAllShapesWithSheetsChartResponse?
    public var groupObjects: GroupObjectsResponse?

    public init(
        createSlide: CreateSlideResponse? = nil,
        createShape: CreateShapeResponse? = nil,
        createTable: CreateTableResponse? = nil,
        replaceAllText: ReplaceAllTextResponse? = nil,
        createImage: CreateImageResponse? = nil,
        createVideo: CreateVideoResponse? = nil,
        createSheetsChart: CreateSheetsChartResponse? = nil,
        createLine: CreateLineResponse? = nil,
        replaceAllShapesWithImage: ReplaceAllShapesWithImageResponse? = nil,
        duplicateObject: DuplicateObjectResponse? = nil,
        replaceAllShapesWithSheetsChart: ReplaceAllShapesWithSheetsChartResponse? = nil,
        groupObjects: GroupObjectsResponse? = nil
    ) {
        self.createSlide = createSlide
        self.createShape = createShape
        self.createTable = createTable
        self.replaceAllText = replaceAllText
        self.createImage = createImage
        self.createVideo = createVideo
        self.createSheetsChart = createSheetsChart
        self.createLine = createLine
        self.replaceAllShapesWithImage = replaceAllShapesWithImage
        self.duplicateObject = duplicateObject
        self.replaceAllShapesWithSheetsChart = replaceAllShapesWithSheetsChart
        self.groupObjects = groupObjects
    }
}

public struct CreateSlideResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct CreateShapeResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct CreateTableResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct ReplaceAllTextResponse: Codable, Hashable, Sendable {
    public var occurrencesChanged: Int?

    public init(
        occurrencesChanged: Int? = nil
    ) {
        self.occurrencesChanged = occurrencesChanged
    }
}

public struct CreateImageResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct CreateVideoResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct CreateSheetsChartResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct CreateLineResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct ReplaceAllShapesWithImageResponse: Codable, Hashable, Sendable {
    public var occurrencesChanged: Int?

    public init(
        occurrencesChanged: Int? = nil
    ) {
        self.occurrencesChanged = occurrencesChanged
    }
}

public struct DuplicateObjectResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct ReplaceAllShapesWithSheetsChartResponse: Codable, Hashable, Sendable {
    public var occurrencesChanged: Int?

    public init(
        occurrencesChanged: Int? = nil
    ) {
        self.occurrencesChanged = occurrencesChanged
    }
}

public struct GroupObjectsResponse: Codable, Hashable, Sendable {
    public var objectId: String?

    public init(
        objectId: String? = nil
    ) {
        self.objectId = objectId
    }
}

public struct WriteControl: Codable, Hashable, Sendable {
    public var requiredRevisionId: String?

    public init(
        requiredRevisionId: String? = nil
    ) {
        self.requiredRevisionId = requiredRevisionId
    }
}

public struct LayoutPlaceholderIdMapping: Codable, Hashable, Sendable {
    public var layoutPlaceholder: Placeholder?
    public var layoutPlaceholderObjectId: String?
    public var objectId: String?

    public init(
        layoutPlaceholder: Placeholder? = nil,
        layoutPlaceholderObjectId: String? = nil,
        objectId: String? = nil
    ) {
        self.layoutPlaceholder = layoutPlaceholder
        self.layoutPlaceholderObjectId = layoutPlaceholderObjectId
        self.objectId = objectId
    }
}

public struct PageElementProperties: Codable, Hashable, Sendable {
    public var pageObjectId: String?
    public var size: Size?
    public var transform: AffineTransform?

    public init(
        pageObjectId: String? = nil,
        size: Size? = nil,
        transform: AffineTransform? = nil
    ) {
        self.pageObjectId = pageObjectId
        self.size = size
        self.transform = transform
    }
}

public struct SubstringMatchCriteria: Codable, Hashable, Sendable {
    public var text: String?
    public var matchCase: Bool?
    public var searchByRegex: Bool?

    public init(
        text: String? = nil,
        matchCase: Bool? = nil,
        searchByRegex: Bool? = nil
    ) {
        self.text = text
        self.matchCase = matchCase
        self.searchByRegex = searchByRegex
    }
}

public struct Range: Codable, Hashable, Sendable {
    public var startIndex: Int?
    public var endIndex: Int?
    public var type: RangeType?

    public init(
        startIndex: Int? = nil,
        endIndex: Int? = nil,
        type: RangeType? = nil
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.type = type
    }
}

public struct TableRange: Codable, Hashable, Sendable {
    public var location: TableCellLocation?
    public var rowSpan: Int?
    public var columnSpan: Int?

    public init(
        location: TableCellLocation? = nil,
        rowSpan: Int? = nil,
        columnSpan: Int? = nil
    ) {
        self.location = location
        self.rowSpan = rowSpan
        self.columnSpan = columnSpan
    }
}

public struct TableCellProperties: Codable, Hashable, Sendable {
    public var tableCellBackgroundFill: TableCellBackgroundFill?
    public var contentAlignment: TableCellPropertiesContentAlignment?

    public init(
        tableCellBackgroundFill: TableCellBackgroundFill? = nil,
        contentAlignment: TableCellPropertiesContentAlignment? = nil
    ) {
        self.tableCellBackgroundFill = tableCellBackgroundFill
        self.contentAlignment = contentAlignment
    }
}

public struct TableBorderProperties: Codable, Hashable, Sendable {
    public var tableBorderFill: TableBorderFill?
    public var weight: Dimension?
    public var dashStyle: TableBorderPropertiesDashStyle?

    public init(
        tableBorderFill: TableBorderFill? = nil,
        weight: Dimension? = nil,
        dashStyle: TableBorderPropertiesDashStyle? = nil
    ) {
        self.tableBorderFill = tableBorderFill
        self.weight = weight
        self.dashStyle = dashStyle
    }
}

public struct TableColumnProperties: Codable, Hashable, Sendable {
    public var columnWidth: Dimension?

    public init(
        columnWidth: Dimension? = nil
    ) {
        self.columnWidth = columnWidth
    }
}

public struct TableRowProperties: Codable, Hashable, Sendable {
    public var minRowHeight: Dimension?

    public init(
        minRowHeight: Dimension? = nil
    ) {
        self.minRowHeight = minRowHeight
    }
}

public struct TableCellBackgroundFill: Codable, Hashable, Sendable {
    public var propertyState: TableCellBackgroundFillPropertyState?
    public var solidFill: SolidFill?

    public init(
        propertyState: TableCellBackgroundFillPropertyState? = nil,
        solidFill: SolidFill? = nil
    ) {
        self.propertyState = propertyState
        self.solidFill = solidFill
    }
}

public struct TableBorderFill: Codable, Hashable, Sendable {
    public var solidFill: SolidFill?

    public init(
        solidFill: SolidFill? = nil
    ) {
        self.solidFill = solidFill
    }
}
