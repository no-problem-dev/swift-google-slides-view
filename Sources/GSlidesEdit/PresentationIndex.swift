import Foundation
import GSlidesRequests
import GSlidesSchema

/// A read-only index of a presentation, built once per preflight pass.
///
/// Holds the object IDs in use (slides and elements share one namespace — catalog:
/// object-id-uniqueness), each element's current transform and size, and the page size. Enough to
/// answer existence and page-bounds questions without re-walking the tree for every request. It is a
/// snapshot: it does not track edits, so a batch that creates an object cannot see it here.
struct PresentationIndex {
    private(set) var slideIds: Set<String> = []
    private(set) var elementIds: Set<String> = []
    private var elements: [String: PageElement] = [:]
    /// The page size in EMU, or nil when the presentation declares none.
    ///
    /// In-memory presentations usually declare none, which is why off-page checks are skipped for
    /// them rather than failed.
    let pageSizeEmu: (w: Double, h: Double)?

    init(_ presentation: Presentation) {
        var ids = Set<String>()
        var els = [String: PageElement]()
        var elementIds = Set<String>()
        func walk(_ elements: [PageElement]) {
            for e in elements {
                elementIds.insert(e.objectId)
                els[e.objectId] = e
                if let children = e.elementGroup?.children { walk(children) }
            }
        }
        for slide in presentation.slides ?? [] {
            ids.insert(slide.objectId)
            walk(slide.pageElements ?? [])
        }
        slideIds = ids
        self.elementIds = elementIds
        elements = els
        if let w = PresentationIndex.emu(presentation.pageSize?.width),
           let h = PresentationIndex.emu(presentation.pageSize?.height) {
            pageSizeEmu = (w, h)
        } else {
            pageSizeEmu = nil
        }
    }

    func elementExists(_ id: String) -> Bool { elementIds.contains(id) }
    func slideExists(_ id: String) -> Bool { slideIds.contains(id) }
    /// Whether the ID is taken by anything. Slides and elements share one namespace, so a new ID
    /// must avoid both.
    func exists(_ id: String) -> Bool { elementIds.contains(id) || slideIds.contains(id) }

    /// The EMU bounding box the element would occupy after applying `transform` under `mode`.
    ///
    /// The upper-left corner comes from the translation, the extent from the element's own size
    /// times the absolute scale, so the box is [tx, tx+w] × [ty, ty+h] (catalog: page-bounds). A nil
    /// `mode` is read as ABSOLUTE, matching the reducer.
    ///
    /// - Returns: nil when no element with that ID is indexed.
    func resultingBox(ofElement id: String, after transform: GSlidesSchema.AffineTransform, mode: UpdatePageElementTransformRequestApplyMode?) -> Box? {
        guard let element = elements[id] else { return nil }
        let existing = element.transform ?? GSlidesEditor.identity
        // The reducer defaults a missing applyMode to ABSOLUTE; mirror that here.
        let isRelative = (mode ?? .absolute) == .relative
        let final = isRelative ? GSlidesEditor.concat(existing, transform) : transform
        let tx = PresentationIndex.emu(final.translateX ?? 0, final.unit)
        let ty = PresentationIndex.emu(final.translateY ?? 0, final.unit)
        let sx = abs(final.scaleX ?? 1)
        let sy = abs(final.scaleY ?? 1)
        let w = (PresentationIndex.emu(element.size?.width) ?? 0) * sx
        let h = (PresentationIndex.emu(element.size?.height) ?? 0) * sy
        return Box(x: tx, y: ty, w: w, h: h)
    }

    // MARK: EMU normalization (1pt = 12700 EMU; unspecified/EMU pass through)

    static func emu(_ dimension: GSlidesSchema.Dimension?) -> Double? {
        guard let dimension, let magnitude = dimension.magnitude else { return nil }
        return emu(magnitude, dimension.unit)
    }

    static func emu(_ magnitude: Double, _ unit: GSlidesSchema.Unit?) -> Double {
        unit == .pt ? magnitude * 12700 : magnitude
    }
}

/// An axis-aligned bounding box on a slide, in EMU, with x, y at the upper-left corner.
struct Box: Equatable {
    var x: Double, y: Double, w: Double, h: Double

    /// Whether the box misses the page rectangle entirely — the element is fully off the slide.
    ///
    /// Partial overlap is fine; only a complete miss counts, matching what the API rejects.
    func isEntirelyOutside(width: Double, height: Double) -> Bool {
        x + w <= 0 || x >= width || y + h <= 0 || y >= height
    }

    func describe() -> String {
        "box x=\(Int(x)) y=\(Int(y)) w=\(Int(w)) h=\(Int(h))"
    }
}
