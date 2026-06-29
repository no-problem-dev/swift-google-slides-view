import GSlidesSchema

/// レンダリングに必要な範囲で Master → Layout → Slide のプレースホルダー継承チェーンを解決する。
/// スライド要素がジオメトリ（size/transform）を省略した場合、対応するレイアウトの
/// プレースホルダーへフォールバックする。
public enum PlaceholderResolver {
    public static func layoutPage(for slide: Page, in presentation: Presentation) -> Page? {
        guard let layoutObjectId = slide.slideProperties?.layoutObjectId else { return nil }
        return presentation.layouts?.first { $0.objectId == layoutObjectId }
    }

    /// スライドのプレースホルダーが継承するレイアウト要素。
    /// 明示的な parentObjectId が優先され、なければ（type, index）でマッチングする。
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

    /// ジオメトリが欠けているスライド要素をレイアウトチェーンで補完した要素の配列。
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
