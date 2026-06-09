public struct RgbColor: Codable, Equatable, Sendable {
    public var red: Double?
    public var green: Double?
    public var blue: Double?

    public init(red: Double? = nil, green: Double? = nil, blue: Double? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
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
