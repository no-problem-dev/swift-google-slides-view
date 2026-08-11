/// A type scale: font family and numeric weight per semantic role, layered onto placeholder
/// defaults the way `ThemeSpec` layers on color.
///
/// The vocabulary stays Slides-native (`fontFamily` and weighted family), and family names come
/// from the caller — a general renderer has no business hard-coding a language's fonts. `.system`
/// leaves every role unset and is the safe default.
public struct PresentationTypography: Sendable, Equatable {
    /// The unit a type scale assigns a family and weight to, derived from a slide's
    /// (layout, placeholder type) pair. Independent of color.
    public enum Role: Sendable, Hashable {
        /// The small category kicker above a content headline.
        case eyebrow
        /// The heading of a slide, section or main point.
        case title
        /// The supporting line under a title.
        case subtitle
        /// Body copy, bullets and captions.
        case body
        /// The oversized metric on a BIG_NUMBER slide.
        case bigNumber
        /// Page number and footer chrome.
        case footer
    }

    /// What a role resolves to.
    ///
    /// Either field may be nil, which defers to the placeholder default — the system font and the
    /// layout's own weight — so a scale that sets only some roles, or only families, composes cleanly.
    public struct RoleStyle: Sendable, Equatable {
        public var fontFamily: String?
        public var weight: Int?     // numeric font weight, 100–900

        public init(fontFamily: String? = nil, weight: Int? = nil) {
            self.fontFamily = fontFamily
            self.weight = weight
        }
    }

    private var styles: [Role: RoleStyle]

    public init(_ styles: [Role: RoleStyle] = [:]) {
        self.styles = styles
    }

    /// The style for a role, or an all-nil `RoleStyle` when this scale does not set one.
    ///
    /// Never nil, so callers can layer the result unconditionally.
    public func style(for role: Role) -> RoleStyle { styles[role] ?? RoleStyle() }

    /// No typography overrides: placeholders keep the system font and their layout's default weight.
    public static let system = PresentationTypography()
}
