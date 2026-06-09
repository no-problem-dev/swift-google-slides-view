/// One theme color → concrete RGB binding (the master's color scheme entry).
public struct ThemeColorPair: Codable, Equatable, Sendable {
    public var type: ThemeColorType?
    public var color: RgbColor?

    public init(type: ThemeColorType? = nil, color: RgbColor? = nil) {
        self.type = type
        self.color = color
    }
}

/// The presentation's palette: theme color name → RGB. Lives on a page's properties
/// (inherited master → layout → slide). This is what resolves `ACCENT1` to a real color.
public struct ColorScheme: Codable, Equatable, Sendable {
    public var colors: [ThemeColorPair]?

    public init(colors: [ThemeColorPair]? = nil) {
        self.colors = colors
    }

    /// Resolves a theme color to its RGB binding, if present in this scheme.
    public func rgb(for themeColor: ThemeColorType) -> RgbColor? {
        colors?.first { $0.type == themeColor }?.color
    }
}

public struct MasterProperties: Codable, Equatable, Sendable {
    public var displayName: String?

    public init(displayName: String? = nil) {
        self.displayName = displayName
    }
}

public struct NotesProperties: Codable, Equatable, Sendable {
    public var speakerNotesObjectId: String?

    public init(speakerNotesObjectId: String? = nil) {
        self.speakerNotesObjectId = speakerNotesObjectId
    }
}
