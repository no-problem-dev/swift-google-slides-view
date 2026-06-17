/// Typography as a design input — a type scale expressed as font family + numeric weight per
/// semantic role, applied to placeholder default styles exactly like `ThemeSpec` applies color.
/// The vocabulary stays Slides-native (`fontFamily` / weighted family weight), and the family name
/// is supplied by the caller (a general renderer must not hardcode a language's font). `.system`
/// (all roles unset) reproduces the historical system-font behavior, so it is a safe default.
public struct PresentationTypography: Sendable, Equatable {
    /// A semantic typographic role, derived from a slide's (layout, placeholder type) — the unit a
    /// type scale assigns a family/weight to, independent of color.
    public enum Role: Sendable, Hashable {
        case eyebrow     // the small category kicker above a content headline
        case title       // slide / section / main-point headings
        case subtitle    // the supporting line under a title
        case body        // body copy, bullets, captions
        case bigNumber   // the oversized metric on a BIG_NUMBER slide
        case footer      // page number / footer chrome
    }

    /// The family + weight a role resolves to. Either field nil leaves that aspect to the placeholder
    /// default (system font / the layout's default weight), so a partial scale composes cleanly.
    public struct RoleStyle: Sendable, Equatable {
        public var fontFamily: String?
        public var weight: Int?     // numeric font weight 100–900

        public init(fontFamily: String? = nil, weight: Int? = nil) {
            self.fontFamily = fontFamily
            self.weight = weight
        }
    }

    private var styles: [Role: RoleStyle]

    public init(_ styles: [Role: RoleStyle] = [:]) {
        self.styles = styles
    }

    /// The style for a role — an empty `RoleStyle` (both nil) when the scale doesn't set it.
    public func style(for role: Role) -> RoleStyle { styles[role] ?? RoleStyle() }

    /// No typography overrides: placeholders keep the system font + their default weight (historical).
    public static let system = PresentationTypography()
}
