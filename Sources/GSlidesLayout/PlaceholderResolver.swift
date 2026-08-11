import GSlidesSchema

/// Fills in the geometry a slide's placeholder elements inherit from their layout.
///
/// The API omits `size` and `transform` on a placeholder that has not been moved or resized, leaving
/// the value on the layout page instead. Without this step such elements have no frame and cannot be
/// drawn. Only size and transform are inherited — text style is not.
public enum PlaceholderResolver {
    /// The layout page this slide points at, or nil when it names none or the layout is missing.
    public static func layoutPage(for slide: Page, in presentation: Presentation) -> Page? {
        guard let layoutObjectId = slide.slideProperties?.layoutObjectId else { return nil }
        return presentation.layouts?.first { $0.objectId == layoutObjectId }
    }

    /// The layout element a slide placeholder inherits from.
    ///
    /// An explicit `parentObjectId` wins; otherwise the first layout placeholder with the same
    /// (type, index) pair is used, treating a missing index as 0.
    public static func parentElement(for element: PageElement, in layout: Page) -> PageElement? {
        guard let placeholder = placeholder(of: element) else { return nil }
        let candidates = layout.pageElements ?? []
        if let parentId = placeholder.parentObjectId {
            return candidates.first { $0.objectId == parentId }
        }
        return candidates.first {
            guard let candidate = self.placeholder(of: $0) else { return false }
            return candidate.type == placeholder.type
                && (candidate.index ?? 0) == (placeholder.index ?? 0)
        }
    }

    /// The slide's elements with missing size and transform filled in from the layout.
    ///
    /// Elements that already carry both are returned untouched, and an element whose parent cannot
    /// be found is passed through still missing its geometry rather than dropped.
    public static func resolvedElements(of slide: Page, in presentation: Presentation) -> [PageElement] {
        let layout = layoutPage(for: slide, in: presentation)
        return (slide.pageElements ?? []).map { element in
            guard element.size == nil || element.transform == nil,
                  let layout,
                  let parent = parentElement(for: element, in: layout)
            else { return element }
            var resolved = element
            resolved.size = resolved.size ?? parent.size
            resolved.transform = resolved.transform ?? parent.transform
            return resolved
        }
    }

    private static func placeholder(of element: PageElement) -> Placeholder? {
        element.shape?.placeholder ?? element.image?.placeholder
    }
}
