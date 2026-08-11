public struct Unit: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "UNIT_UNSPECIFIED")
    public static let emu = Self(rawValue: "EMU")
    public static let pt = Self(rawValue: "PT")

    public static var knownValues: [Self] { [.unspecified, .emu, .pt] }
}

/// A length as a bare number plus the unit it is measured in.
///
/// Read `unit` before using `magnitude` — the API returns EMU for geometry and points for font
/// sizes, and 1 pt = 12,700 EMU. An unspecified unit means EMU. `GSlidesLayout` adds
/// `emuMagnitude` / `pointMagnitude` for the conversion.
public struct Dimension: Codable, Equatable, Sendable {
    public var magnitude: Double?
    public var unit: Unit?

    public init(magnitude: Double? = nil, unit: Unit? = nil) {
        self.magnitude = magnitude
        self.unit = unit
    }
}

/// A width and height, each carrying its own unit.
///
/// For a page element this is the *unscaled* size; the element's transform scales it, so the drawn
/// size is width × scaleX by height × scaleY.
public struct Size: Codable, Equatable, Sendable {
    public var width: Dimension?
    public var height: Dimension?

    public init(width: Dimension? = nil, height: Dimension? = nil) {
        self.width = width
        self.height = height
    }
}

/// The 2×3 transform that places an element on the page, in page coordinates whose origin is the
/// top-left corner with y growing downward.
///
/// Applied as `x' = scaleX·x + shearX·y + translateX` and `y' = shearY·x + scaleY·y + translateY`,
/// so translation is applied last. `unit` governs `translateX` / `translateY` only — the scale and
/// shear components are ratios and carry no unit. A nil component defaults to the identity value
/// (1 for scale, 0 for shear and translation), not to 0 across the board.
///
/// `translateX` / `translateY` locate the element's upper-left corner (catalog: page-bounds). A
/// negative scale is a flip about that corner, which puts the drawn rectangle above or to the left
/// of the translation point.
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
