/// One entry of a master's color scheme: a theme color slot bound to a concrete RGB value.
public struct ThemeColorPair: Codable, Equatable, Sendable {
    public var type: ThemeColorType?
    public var color: RgbColor?

    public init(type: ThemeColorType? = nil, color: RgbColor? = nil) {
        self.type = type
        self.color = color
    }
}

/// A presentation's palette: theme color name to RGB.
///
/// Lives on page properties and inherits master → layout → slide. This is what turns `ACCENT1` into
/// an actual color at render time, so changing it on the master restyles the whole deck.
public struct ColorScheme: Codable, Equatable, Sendable {
    public var colors: [ThemeColorPair]?

    public init(colors: [ThemeColorPair]? = nil) {
        self.colors = colors
    }

    /// The RGB this scheme binds to a theme color, or nil when the scheme leaves it unbound.
    ///
    /// Does not walk the master → layout → slide inheritance chain; it reads this scheme only.
    public func rgb(for themeColor: ThemeColorType) -> RgbColor? {
        colors?.first { $0.type == themeColor }?.color
    }

    /// The editable slots this scheme leaves unbound.
    ///
    /// A color scheme update must supply all 12, so a non-empty result means this scheme cannot be
    /// written back to a master. (catalog: theme-color-scheme-editable)
    public var missingEditableSlots: [ThemeColorType] {
        let bound = Set((colors ?? []).compactMap { $0.type?.rawValue })
        return ThemeColorType.editableSlots.filter { !bound.contains($0.rawValue) }
    }

    /// The bound slots whose RGB components fall outside the specified 0.0–1.0 range.
    public var outOfRangeSlots: [ThemeColorType] {
        (colors ?? []).compactMap { pair in
            guard let type = pair.type, let color = pair.color, !color.componentsInRange else { return nil }
            return type
        }
    }

    /// Whether this scheme can be sent as a color scheme update: all 12 editable slots bound and
    /// every component in range.
    public var isCompleteEditableScheme: Bool {
        missingEditableSlots.isEmpty && outOfRangeSlots.isEmpty
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
