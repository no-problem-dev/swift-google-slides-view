import GSlidesSchema

/// Resolves the Master → Layout → Slide placeholder inheritance chain
/// far enough for rendering: geometry (size/transform) falls back to the
/// matching layout placeholder when a slide element omits it.
public enum PlaceholderResolver {
    public static func layoutPage(for slide: Page, in presentation: Presentation) -> Page? {
        guard let layoutObjectId = slide.slideProperties?.layoutObjectId else { return nil }
        return presentation.layouts?.first { $0.objectId == layoutObjectId }
    }

    /// The layout element a slide placeholder inherits from:
    /// explicit parentObjectId wins, otherwise match by (type, index).
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

    /// Slide elements with missing geometry filled in from the layout chain.
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
