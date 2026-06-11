import Foundation
import GSlidesRequests
import GSlidesSchema

/// A read-only index over a `Presentation`, built once per preflight pass: which object IDs exist
/// (slides + elements, the shared namespace per catalog: object-id-uniqueness), each element's
/// current transform/size, and the page size — everything the validator needs to answer existence
/// and page-bounds questions without re-walking the tree per request.
struct PresentationIndex {
    private(set) var slideIds: Set<String> = []
    private(set) var elementIds: Set<String> = []
    private var elements: [String: PageElement] = [:]
    /// Page size in EMU, if the presentation declares one (in-memory presentations often don't).
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
    /// Shared namespace: an ID is taken if any slide OR element uses it.
    func exists(_ id: String) -> Bool { elementIds.contains(id) || slideIds.contains(id) }

    /// The EMU bounding box an element would occupy after applying `transform` in `mode` — top-left
    /// from the translate elements, extent from the element's intrinsic size scaled by the
    /// transform. Returns nil if the element is unknown. `translate` is the UPPER-LEFT corner
    /// (catalog: page-bounds), so the box is [tx, tx+w] × [ty, ty+h].
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

/// An axis-aligned EMU bounding box on a slide.
struct Box: Equatable {
    var x: Double, y: Double, w: Double, h: Double

    /// No overlap at all with the page rect [0,width] × [0,height] — the element is fully off-slide.
    func isEntirelyOutside(width: Double, height: Double) -> Bool {
        x + w <= 0 || x >= width || y + h <= 0 || y >= height
    }

    func describe() -> String {
        "box x=\(Int(x)) y=\(Int(y)) w=\(Int(w)) h=\(Int(h))"
    }
}
