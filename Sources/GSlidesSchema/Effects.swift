public struct PropertyState: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let rendered = Self(rawValue: "RENDERED")
    public static let notRendered = Self(rawValue: "NOT_RENDERED")
    public static let inherit = Self(rawValue: "INHERIT")

    public static var knownValues: [Self] { [.rendered, .notRendered, .inherit] }
}

public struct DashStyle: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "DASH_STYLE_UNSPECIFIED")
    public static let solid = Self(rawValue: "SOLID")
    public static let dot = Self(rawValue: "DOT")
    public static let dash = Self(rawValue: "DASH")
    public static let dashDot = Self(rawValue: "DASH_DOT")
    public static let longDash = Self(rawValue: "LONG_DASH")
    public static let longDashDot = Self(rawValue: "LONG_DASH_DOT")

    public static var knownValues: [Self] {
        [.unspecified, .solid, .dot, .dash, .dashDot, .longDash, .longDashDot]
    }
}

public struct ShadowType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "SHADOW_TYPE_UNSPECIFIED")
    public static let outer = Self(rawValue: "OUTER")

    public static var knownValues: [Self] { [.unspecified, .outer] }
}

public struct RectanglePosition: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "RECTANGLE_POSITION_UNSPECIFIED")
    public static let topLeft = Self(rawValue: "TOP_LEFT")
    public static let topCenter = Self(rawValue: "TOP_CENTER")
    public static let topRight = Self(rawValue: "TOP_RIGHT")
    public static let leftCenter = Self(rawValue: "LEFT_CENTER")
    public static let center = Self(rawValue: "CENTER")
    public static let rightCenter = Self(rawValue: "RIGHT_CENTER")
    public static let bottomLeft = Self(rawValue: "BOTTOM_LEFT")
    public static let bottomCenter = Self(rawValue: "BOTTOM_CENTER")
    public static let bottomRight = Self(rawValue: "BOTTOM_RIGHT")

    public static var knownValues: [Self] {
        [
            .unspecified, .topLeft, .topCenter, .topRight, .leftCenter,
            .center, .rightCenter, .bottomLeft, .bottomCenter, .bottomRight,
        ]
    }
}

public struct Shadow: Codable, Hashable, Sendable {
    public var type: ShadowType?
    public var transform: AffineTransform?
    public var alignment: RectanglePosition?
    public var blurRadius: Dimension?
    public var color: OpaqueColor?
    public var alpha: Double?
    public var rotateWithShape: Bool?
    public var propertyState: PropertyState?

    public init(
        type: ShadowType? = nil,
        transform: AffineTransform? = nil,
        alignment: RectanglePosition? = nil,
        blurRadius: Dimension? = nil,
        color: OpaqueColor? = nil,
        alpha: Double? = nil,
        rotateWithShape: Bool? = nil,
        propertyState: PropertyState? = nil
    ) {
        self.type = type
        self.transform = transform
        self.alignment = alignment
        self.blurRadius = blurRadius
        self.color = color
        self.alpha = alpha
        self.rotateWithShape = rotateWithShape
        self.propertyState = propertyState
    }
}

public struct CropProperties: Codable, Hashable, Sendable {
    public var leftOffset: Double?
    public var rightOffset: Double?
    public var topOffset: Double?
    public var bottomOffset: Double?
    public var angle: Double?

    public init(
        leftOffset: Double? = nil,
        rightOffset: Double? = nil,
        topOffset: Double? = nil,
        bottomOffset: Double? = nil,
        angle: Double? = nil
    ) {
        self.leftOffset = leftOffset
        self.rightOffset = rightOffset
        self.topOffset = topOffset
        self.bottomOffset = bottomOffset
        self.angle = angle
    }
}

public struct RecolorName: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let none = Self(rawValue: "NONE")
    public static let grayscale = Self(rawValue: "GRAYSCALE")
    public static let negative = Self(rawValue: "NEGATIVE")
    public static let sepia = Self(rawValue: "SEPIA")
    public static let custom = Self(rawValue: "CUSTOM")
    public static let light1 = Self(rawValue: "LIGHT1")
    public static let dark1 = Self(rawValue: "DARK1")

    public static var knownValues: [Self] {
        // LIGHT1..LIGHT10 / DARK1..DARK10 plus the named modes.
        var values: [Self] = [.none, .grayscale, .negative, .sepia, .custom]
        for i in 1...10 { values.append(Self(rawValue: "LIGHT\(i)")) }
        for i in 1...10 { values.append(Self(rawValue: "DARK\(i)")) }
        return values
    }
}

public struct ColorStop: Codable, Hashable, Sendable {
    public var color: OpaqueColor?
    public var alpha: Double?
    public var position: Double?

    public init(color: OpaqueColor? = nil, alpha: Double? = nil, position: Double? = nil) {
        self.color = color
        self.alpha = alpha
        self.position = position
    }
}

public struct Recolor: Codable, Hashable, Sendable {
    public var recolorStops: [ColorStop]?
    public var name: RecolorName?

    public init(recolorStops: [ColorStop]? = nil, name: RecolorName? = nil) {
        self.recolorStops = recolorStops
        self.name = name
    }
}

public struct Link: Codable, Hashable, Sendable {
    public var url: String?
    public var relativeLink: String?
    public var pageObjectId: String?
    public var slideIndex: Int?

    public init(
        url: String? = nil,
        relativeLink: String? = nil,
        pageObjectId: String? = nil,
        slideIndex: Int? = nil
    ) {
        self.url = url
        self.relativeLink = relativeLink
        self.pageObjectId = pageObjectId
        self.slideIndex = slideIndex
    }
}

public struct WeightedFontFamily: Codable, Hashable, Sendable {
    public var fontFamily: String?
    public var weight: Int?

    public init(fontFamily: String? = nil, weight: Int? = nil) {
        self.fontFamily = fontFamily
        self.weight = weight
    }
}
