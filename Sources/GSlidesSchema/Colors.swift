/// A color in the RGB color space, with each component a 0.0–1.0 Double — not a 0–255 integer.
///
/// An unset component is treated as 0, so a color with only `red` set is a pure red.
/// Mirrors `google.apps.slides.v1.RgbColor`.
public struct RgbColor: Codable, Equatable, Sendable {
    public var red: Double?
    public var green: Double?
    public var blue: Double?

    public init(red: Double? = nil, green: Double? = nil, blue: Double? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Creates a color from a `#RRGGBB` or `RRGGBB` hex string, dividing each byte by 255.
    ///
    /// Three-digit shorthand and eight-digit alpha forms are not accepted.
    ///
    /// - Parameter hex: Six hex digits, optionally prefixed with `#`; surrounding whitespace is trimmed.
    /// - Returns: nil for anything that is not exactly six hex digits.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Whether every set component lies within the specified 0.0–1.0 range.
    ///
    /// Unset components pass, matching the optional-field decode model — an all-nil color is in range.
    public var componentsInRange: Bool {
        [red, green, blue].allSatisfy { $0.map { (0.0...1.0).contains($0) } ?? true }
    }
}

public struct ThemeColorType: SpecEnum {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let unspecified = Self(rawValue: "THEME_COLOR_TYPE_UNSPECIFIED")
    public static let dark1 = Self(rawValue: "DARK1")
    public static let light1 = Self(rawValue: "LIGHT1")
    public static let dark2 = Self(rawValue: "DARK2")
    public static let light2 = Self(rawValue: "LIGHT2")
    public static let accent1 = Self(rawValue: "ACCENT1")
    public static let accent2 = Self(rawValue: "ACCENT2")
    public static let accent3 = Self(rawValue: "ACCENT3")
    public static let accent4 = Self(rawValue: "ACCENT4")
    public static let accent5 = Self(rawValue: "ACCENT5")
    public static let accent6 = Self(rawValue: "ACCENT6")
    public static let hyperlink = Self(rawValue: "HYPERLINK")
    public static let followedHyperlink = Self(rawValue: "FOLLOWED_HYPERLINK")
    public static let text1 = Self(rawValue: "TEXT1")
    public static let background1 = Self(rawValue: "BACKGROUND1")
    public static let text2 = Self(rawValue: "TEXT2")
    public static let background2 = Self(rawValue: "BACKGROUND2")

    public static var knownValues: [Self] {
        [
            .unspecified, .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink, .text1, .background1, .text2, .background2,
        ]
    }

    /// The 12 theme colors the API lets you set, in discovery enum order.
    ///
    /// They can be set on a `Master` page only, and a color scheme update must supply all 12 at once.
    /// The other four — TEXT1, BACKGROUND1, TEXT2, BACKGROUND2 — are derived and ignored on update.
    /// (catalog: theme-color-scheme-editable)
    public static var editableSlots: [Self] {
        [
            .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink,
        ]
    }

    /// Whether this slot's concrete color can be set through the API — one of the 12 editable slots.
    public var isEditableSlot: Bool { Self.editableSlots.contains { $0.rawValue == rawValue } }
}

/// A fully opaque color, given either as explicit RGB or as a reference to a theme color slot.
///
/// A theme color resolves at render time against the master's color scheme, so it recolors with the
/// deck; an explicit RGB does not. Mirrors `google.apps.slides.v1.OpaqueColor`.
public struct OpaqueColor: Codable, Equatable, Sendable {
    public var rgbColor: RgbColor?
    public var themeColor: ThemeColorType?

    public init(rgbColor: RgbColor? = nil, themeColor: ThemeColorType? = nil) {
        self.rgbColor = rgbColor
        self.themeColor = themeColor
    }
}

/// A color that may be absent, meaning transparent rather than "inherit".
///
/// Used where the Slides API lets you explicitly clear paint. Mirrors
/// `google.apps.slides.v1.OptionalColor`.
public struct OptionalColor: Codable, Equatable, Sendable {
    public var opaqueColor: OpaqueColor?

    public init(opaqueColor: OpaqueColor? = nil) {
        self.opaqueColor = opaqueColor
    }
}

/// A single-color fill whose `alpha` runs from 0.0 (transparent) to 1.0 (fully opaque).
///
/// A nil `alpha` means fully opaque — the Slides API default is 1.0, not 0.
/// Mirrors `google.apps.slides.v1.SolidFill`.
public struct SolidFill: Codable, Equatable, Sendable {
    public var color: OpaqueColor?
    public var alpha: Double?

    public init(color: OpaqueColor? = nil, alpha: Double? = nil) {
        self.color = color
        self.alpha = alpha
    }
}
