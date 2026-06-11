public struct RgbColor: Codable, Equatable, Sendable {
    public var red: Double?
    public var green: Double?
    public var blue: Double?

    public init(red: Double? = nil, green: Double? = nil, blue: Double? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Build from a `#RRGGBB` / `RRGGBB` hex string. The Slides API stores each component as a float
    /// "from 0.0 to 1.0" (discovery: `RgbColor.red/green/blue`), so each byte is divided by 255 — the
    /// conversion the human-facing hex form requires. Returns nil for non-6-digit-hex input.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Whether every set component lies in the API's documented 0.0–1.0 range. Unset components pass
    /// (they're simply absent), matching the field-optional decoding model.
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

    /// The 12 ThemeColorTypes whose concrete colors are editable via the API, in discovery enum
    /// order. Per the spec, ONLY these can be set, ONLY on a `Master` page, and ALL 12 must be
    /// provided when updating a color scheme; the remaining four (TEXT1, BACKGROUND1, TEXT2,
    /// BACKGROUND2) are ignored on update. (catalog: theme-color-scheme-editable)
    public static var editableSlots: [Self] {
        [
            .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink,
        ]
    }

    /// Whether this slot's concrete color is editable via the API (one of the first 12).
    public var isEditableSlot: Bool { Self.editableSlots.contains { $0.rawValue == rawValue } }
}

public struct OpaqueColor: Codable, Equatable, Sendable {
    public var rgbColor: RgbColor?
    public var themeColor: ThemeColorType?

    public init(rgbColor: RgbColor? = nil, themeColor: ThemeColorType? = nil) {
        self.rgbColor = rgbColor
        self.themeColor = themeColor
    }
}

public struct OptionalColor: Codable, Equatable, Sendable {
    public var opaqueColor: OpaqueColor?

    public init(opaqueColor: OpaqueColor? = nil) {
        self.opaqueColor = opaqueColor
    }
}

public struct SolidFill: Codable, Equatable, Sendable {
    public var color: OpaqueColor?
    public var alpha: Double?

    public init(color: OpaqueColor? = nil, alpha: Double? = nil) {
        self.color = color
        self.alpha = alpha
    }
}
