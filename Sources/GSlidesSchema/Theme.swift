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

    /// The editable slots (of the 12) that this scheme leaves unbound. Must be EMPTY for an API
    /// color-scheme update, which requires all 12 first ThemeColorTypes. (catalog:
    /// theme-color-scheme-editable)
    public var missingEditableSlots: [ThemeColorType] {
        let bound = Set((colors ?? []).compactMap { $0.type?.rawValue })
        return ThemeColorType.editableSlots.filter { !bound.contains($0.rawValue) }
    }

    /// Bound colors whose RGB components fall outside the documented 0.0–1.0 range, paired with the
    /// offending slot.
    public var outOfRangeSlots: [ThemeColorType] {
        (colors ?? []).compactMap { pair in
            guard let type = pair.type, let color = pair.color, !color.componentsInRange else { return nil }
            return type
        }
    }

    /// Whether this scheme is a valid, settable color scheme: all 12 editable slots bound and every
    /// bound color in range.
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
