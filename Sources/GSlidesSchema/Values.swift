public struct Unit: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "UNIT_UNSPECIFIED")
    public static let emu = Self(rawValue: "EMU")
    public static let pt = Self(rawValue: "PT")

    public static var knownValues: [Self] { [.unspecified, .emu, .pt] }
}

public struct Dimension: Codable, Equatable, Sendable {
    public var magnitude: Double?
    public var unit: Unit?

    public init(magnitude: Double? = nil, unit: Unit? = nil) {
        self.magnitude = magnitude
        self.unit = unit
    }
}

public struct Size: Codable, Equatable, Sendable {
    public var width: Dimension?
    public var height: Dimension?

    public init(width: Dimension? = nil, height: Dimension? = nil) {
        self.width = width
        self.height = height
    }
}

public struct AffineTransform: Codable, Equatable, Sendable {
    public var scaleX: Double?
    public var scaleY: Double?
    public var shearX: Double?
    public var shearY: Double?
    public var translateX: Double?
    public var translateY: Double?
    public var unit: Unit?

    public init(
        scaleX: Double? = nil,
        scaleY: Double? = nil,
        shearX: Double? = nil,
        shearY: Double? = nil,
        translateX: Double? = nil,
        translateY: Double? = nil,
        unit: Unit? = nil
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.shearX = shearX
        self.shearY = shearY
        self.translateX = translateX
        self.translateY = translateY
        self.unit = unit
    }
}
