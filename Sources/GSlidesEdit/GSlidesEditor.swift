import Foundation
import GSlidesRequests
import GSlidesSchema

public enum GSlidesEditError: Error, Equatable, Sendable {
    case objectNotFound(String)
    /// A request kind the local reducer doesn't execute yet (it still round-trips on the wire).
    case unsupportedRequest(String)
    case invalidRequest(String)
}

public extension Presentation {
    /// Apply a sequence of batchUpdate requests to this presentation, returning the new value.
    /// Pure (no I/O, no Google dependency): the official `Request` vocabulary, executed locally.
    /// Index convention for text edits: positions count `textRun` content only; paragraph markers
    /// and auto-text are zero-width. This is the reducer's own, internally-consistent convention —
    /// the agent reads our indices and edits against them, so no Google round-trip is involved.
    func applying(_ requests: [Request]) throws -> Presentation {
        var p = self
        for request in requests { try GSlidesEditor.apply(request, to: &p) }
        return p
    }

    /// Best-effort variant for live editing: apply each request independently, skipping any that
    /// fail (unknown objectId, unsupported op) rather than aborting the whole batch. An agent that
    /// gets one of N edits slightly wrong still sees the other N-1 take effect. Returns the result
    /// and the skipped errors (for logging).
    func applyingLenient(_ requests: [Request]) -> (presentation: Presentation, skipped: [Error]) {
        var p = self
        var skipped: [Error] = []
        for request in requests {
            do { try GSlidesEditor.apply(request, to: &p) } catch { skipped.append(error) }
        }
        return (p, skipped)
    }
}

/// Local `batchUpdate` executor. Sits on the frozen Schema+Requests mirror; everything above
/// (A2A diff delivery, the agent edit loop) drives the deck through this one entry point.
public enum GSlidesEditor {
    public static func apply(_ requests: [Request], to presentation: Presentation) throws -> Presentation {
        try presentation.applying(requests)
    }

    static func apply(_ request: Request, to p: inout Presentation) throws {
        switch request.kind {
        case .deleteObject(let r): try deleteObject(r, &p)
        case .updatePageElementTransform(let r): try updateTransform(r, &p)
        case .updatePageElementsZOrder(let r): try updateZOrder(r, &p)
        case .duplicateObject(let r): try duplicate(r, &p)
        case .createSlide(let r): try createSlide(r, &p)
        case .replaceAllText(let r): replaceAllText(r, &p)
        case .insertText(let r): try insertText(r, &p)
        case .deleteText(let r): try deleteText(r, &p)
        case .updateTextStyle(let r): try updateTextStyle(r, &p)
        case .updateShapeProperties(let r): try updateShapeProperties(r, &p)
        case .other: throw GSlidesEditError.invalidRequest("empty request (no member set)")
        default: throw GSlidesEditError.unsupportedRequest(label(request))
        }
    }

    /// The wire field name of a request's set member (for diagnostics) — data-driven, no 44-case switch.
    static func label(_ request: Request) -> String {
        for child in Mirror(reflecting: request).children {
            if let name = child.label, Mirror(reflecting: child.value).displayStyle == .optional,
               Mirror(reflecting: child.value).children.first != nil {
                return name
            }
        }
        return "unknown"
    }
}

// MARK: - Element traversal

extension GSlidesEditor {
    /// Find an element by id anywhere (recursing into groups) and mutate it in place.
    static func mutateElement(_ id: String, in p: inout Presentation, _ body: (inout PageElement) -> Void) throws {
        var slides = p.slides ?? []
        for s in slides.indices {
            var elements = slides[s].pageElements ?? []
            if Self.withElement(id, in: &elements, body) {
                slides[s].pageElements = elements
                p.slides = slides
                return
            }
        }
        throw GSlidesEditError.objectNotFound(id)
    }

    static func withElement(_ id: String, in elements: inout [PageElement], _ body: (inout PageElement) -> Void) -> Bool {
        for i in elements.indices {
            if elements[i].objectId == id { body(&elements[i]); return true }
            if var group = elements[i].elementGroup, var children = group.children {
                if withElement(id, in: &children, body) {
                    group.children = children
                    elements[i].elementGroup = group
                    return true
                }
            }
        }
        return false
    }

    static func removeElement(_ id: String, from elements: inout [PageElement]) -> Bool {
        if let idx = elements.firstIndex(where: { $0.objectId == id }) {
            elements.remove(at: idx)
            return true
        }
        for i in elements.indices {
            if var group = elements[i].elementGroup, var children = group.children {
                if removeElement(id, from: &children) {
                    group.children = children
                    elements[i].elementGroup = group
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Structural ops

extension GSlidesEditor {
    static func deleteObject(_ r: DeleteObjectRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId else { throw GSlidesEditError.invalidRequest("deleteObject.objectId") }
        var slides = p.slides ?? []
        for s in slides.indices {
            var elements = slides[s].pageElements ?? []
            if removeElement(id, from: &elements) {
                slides[s].pageElements = elements
                p.slides = slides
                return
            }
        }
        if let idx = slides.firstIndex(where: { $0.objectId == id }) {  // a whole slide
            slides.remove(at: idx)
            p.slides = slides
            return
        }
        throw GSlidesEditError.objectNotFound(id)
    }

    static func createSlide(_ r: CreateSlideRequest, _ p: inout Presentation) throws {
        var slides = p.slides ?? []
        let id = r.objectId ?? "slide-\(slides.count + 1)"
        let page = Page(objectId: id, pageType: .slide, pageElements: [])
        let index = r.insertionIndex.map { min(max(0, $0), slides.count) } ?? slides.count
        slides.insert(page, at: index)
        p.slides = slides
    }

    static func duplicate(_ r: DuplicateObjectRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId else { throw GSlidesEditError.invalidRequest("duplicateObject.objectId") }
        var slides = p.slides ?? []
        for s in slides.indices {
            var elements = slides[s].pageElements ?? []
            guard let idx = elements.firstIndex(where: { $0.objectId == id }) else { continue }
            var copy = elements[idx]
            copy.objectId = r.objectIds?[id] ?? "\(id)-copy"
            elements.insert(copy, at: idx + 1)
            slides[s].pageElements = elements
            p.slides = slides
            return
        }
        throw GSlidesEditError.objectNotFound(id)
    }

    static func updateZOrder(_ r: UpdatePageElementsZOrderRequest, _ p: inout Presentation) throws {
        guard let ids = r.pageElementObjectIds, !ids.isEmpty else { return }
        let op = r.operation ?? .zOrderOperationUnspecified
        var slides = p.slides ?? []
        for s in slides.indices {
            var elements = slides[s].pageElements ?? []
            let positions = ids.compactMap { id in elements.firstIndex(where: { $0.objectId == id }) }
            guard positions.count == ids.count else { continue }  // all on the same page
            let moving = positions.sorted().map { elements[$0] }
            elements.removeAll { e in ids.contains(e.objectId) }
            switch op {
            case .bringToFront: elements.append(contentsOf: moving)
            case .sendToBack: elements.insert(contentsOf: moving, at: 0)
            case .bringForward:
                let anchor = min((positions.max() ?? 0) + 1, elements.count)
                elements.insert(contentsOf: moving, at: anchor)
            case .sendBackward:
                let anchor = max((positions.min() ?? 1) - 1, 0)
                elements.insert(contentsOf: moving, at: anchor)
            default: return
            }
            slides[s].pageElements = elements
            p.slides = slides
            return
        }
        throw GSlidesEditError.objectNotFound(ids.joined(separator: ","))
    }
}

// MARK: - Geometry

extension GSlidesEditor {
    static func updateTransform(_ r: UpdatePageElementTransformRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let t = r.transform else {
            throw GSlidesEditError.invalidRequest("updatePageElementTransform")
        }
        let mode = r.applyMode ?? .absolute
        try mutateElement(id, in: &p) { element in
            switch mode {
            case .relative:
                element.transform = concat(element.transform ?? Self.identity, t)
            default:
                element.transform = t
            }
        }
    }

    static let identity = GSlidesSchema.AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0)

    /// 2×3 affine concatenation: result applies `update` on top of `existing` (existing first).
    static func concat(_ existing: GSlidesSchema.AffineTransform, _ update: GSlidesSchema.AffineTransform) -> GSlidesSchema.AffineTransform {
        let (esx, esy, ehx, ehy, etx, ety) = coalesce(existing)
        let (usx, usy, uhx, uhy, utx, uty) = coalesce(update)
        return GSlidesSchema.AffineTransform(
            scaleX: esx * usx + ehx * uhy,
            scaleY: ehy * uhx + esy * usy,
            shearX: esx * uhx + ehx * usy,
            shearY: ehy * usx + esy * uhy,
            translateX: esx * utx + ehx * uty + etx,
            translateY: ehy * utx + esy * uty + ety,
            unit: existing.unit ?? update.unit
        )
    }

    /// (sx, sy, hx, hy, tx, ty) with nils defaulted to the identity components.
    static func coalesce(_ t: GSlidesSchema.AffineTransform) -> (Double, Double, Double, Double, Double, Double) {
        (t.scaleX ?? 1, t.scaleY ?? 1, t.shearX ?? 0, t.shearY ?? 0, t.translateX ?? 0, t.translateY ?? 0)
    }
}

// MARK: - Text ops

extension GSlidesEditor {
    static func replaceAllText(_ r: ReplaceAllTextRequest, _ p: inout Presentation) {
        guard let find = r.containsText?.text, !find.isEmpty else { return }
        let replacement = r.replaceText ?? ""
        let caseSensitive = r.containsText?.matchCase ?? false
        let pages = Set(r.pageObjectIds ?? [])
        var slides = p.slides ?? []
        for s in slides.indices {
            if !pages.isEmpty, !pages.contains(slides[s].objectId) { continue }
            var elements = slides[s].pageElements ?? []
            mutateAllText(in: &elements) { content in
                content = caseSensitive
                    ? content.replacingOccurrences(of: find, with: replacement)
                    : content.replacingOccurrences(of: find, with: replacement, options: .caseInsensitive)
            }
            slides[s].pageElements = elements
        }
        p.slides = slides
    }

    /// Walk every shape's text runs (recursing into groups) and transform each run's content.
    static func mutateAllText(in elements: inout [PageElement], _ transform: (inout String) -> Void) {
        for i in elements.indices {
            if var shape = elements[i].shape, var tc = shape.text, var els = tc.textElements {
                for j in els.indices {
                    if var run = els[j].textRun, var content = run.content {
                        transform(&content)
                        run.content = content
                        els[j].textRun = run
                    }
                }
                tc.textElements = els
                shape.text = tc
                elements[i].shape = shape
            }
            if var group = elements[i].elementGroup, var children = group.children {
                mutateAllText(in: &children, transform)
                group.children = children
                elements[i].elementGroup = group
            }
        }
    }

    static func insertText(_ r: InsertTextRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let text = r.text, !text.isEmpty else {
            throw GSlidesEditError.invalidRequest("insertText")
        }
        if r.cellLocation != nil { throw GSlidesEditError.unsupportedRequest("insertText(table cell)") }
        try editText(id, in: &p) { els in
            splice(&els, at: r.insertionIndex ?? 0, removing: 0, inserting: text)
        }
    }

    static func deleteText(_ r: DeleteTextRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId else { throw GSlidesEditError.invalidRequest("deleteText") }
        if r.cellLocation != nil { throw GSlidesEditError.unsupportedRequest("deleteText(table cell)") }
        try editText(id, in: &p) { els in
            let (start, end) = resolveRange(r.textRange, total: textLength(els))
            guard end > start else { return }
            splice(&els, at: start, removing: end - start, inserting: "")
        }
    }

    static func updateTextStyle(_ r: UpdateTextStyleRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let style = r.style else {
            throw GSlidesEditError.invalidRequest("updateTextStyle")
        }
        if r.cellLocation != nil { throw GSlidesEditError.unsupportedRequest("updateTextStyle(table cell)") }
        let fields = r.fields ?? "*"
        var thrown: Error?
        try editText(id, in: &p) { els in
            let (start, end) = resolveRange(r.textRange, total: textLength(els))
            // Whole runs overlapping [start,end) are restyled (no mid-run splitting in this slice).
            let targets = runRanges(els).filter { $0.start < end && $0.end > start }
            for run in targets {
                let base = els[run.index].textRun?.style
                do { els[run.index].textRun?.style = try FieldMask.merge(base: base, patch: style, fields: fields) }
                catch { thrown = error }
            }
        }
        if let thrown { throw thrown }
    }

    /// Edit a shape's text elements in place, preserving paragraph markers and the compact
    /// (marker+run on one element) form, then re-derive flattened indices.
    static func editText(_ id: String, in p: inout Presentation, _ body: (inout [TextElement]) -> Void) throws {
        try mutateElement(id, in: &p) { element in
            guard var shape = element.shape else { return }
            var tc = shape.text ?? TextContent(textElements: [])
            var els = tc.textElements ?? []
            body(&els)
            reindex(&els)
            tc.textElements = els
            shape.text = tc
            element.shape = shape
        }
    }

    static func textLength(_ els: [TextElement]) -> Int {
        els.reduce(0) { $0 + ($1.textRun?.content?.count ?? 0) }
    }

    /// Flattened [start,end) of each run-bearing element, in element order.
    static func runRanges(_ els: [TextElement]) -> [(index: Int, start: Int, end: Int)] {
        var out: [(Int, Int, Int)] = []
        var cursor = 0
        for (i, el) in els.enumerated() {
            let len = el.textRun?.content?.count ?? 0
            if el.textRun != nil { out.append((i, cursor, cursor + len)) }
            cursor += len
        }
        return out
    }

    static func reindex(_ els: inout [TextElement]) {
        var index = 0
        for i in els.indices {
            let len = els[i].textRun?.content?.count ?? 0
            els[i].startIndex = index
            els[i].endIndex = index + len
            index += len
        }
    }

    /// Splice at a flattened character offset, keeping each character bound to its originating run
    /// element (markers preserved). Inserted text joins the run at the insertion point, inheriting
    /// its style. Run-only elements emptied by a delete are dropped; marker-bearing ones are kept.
    static func splice(_ els: inout [TextElement], at offset: Int, removing: Int, inserting: String) {
        let runs = runRanges(els)
        if runs.isEmpty {  // empty shape — seed a single run
            if inserting.isEmpty { return }
            els.append(TextElement(textRun: TextRun(content: inserting)))
            return
        }
        let total = textLength(els)
        // Build a per-character list tagged with its run element index.
        var cells: [(ch: Character, elem: Int)] = []
        for run in runs {
            for ch in els[run.index].textRun?.content ?? "" { cells.append((ch, run.index)) }
        }
        let start = min(max(0, offset), total)
        let end = min(total, start + max(0, removing))
        // Inherit the run at the insertion point; fall back to the last/first run element when the
        // shape is currently empty (e.g. after a delete-all, where a marker-bearing run remains).
        let insertElem = start < cells.count ? cells[start].elem : (cells.last?.elem ?? runs[0].index)
        cells.removeSubrange(start..<end)
        cells.insert(contentsOf: inserting.map { ($0, insertElem) }, at: start)
        // Regroup characters back into their run elements.
        var content: [Int: String] = [:]
        for cell in cells { content[cell.elem, default: ""].append(cell.ch) }
        var dropped: [Int] = []
        for run in runs {
            let text = content[run.index] ?? ""
            if text.isEmpty, els[run.index].paragraphMarker == nil {
                dropped.append(run.index)  // run-only and now empty
            } else {
                els[run.index].textRun?.content = text
            }
        }
        for i in dropped.sorted(by: >) { els.remove(at: i) }
    }

    static func resolveRange(_ range: Range?, total: Int) -> (Int, Int) {
        guard let range else { return (0, total) }
        switch range.type ?? .all {
        case .fixedRange: return (range.startIndex ?? 0, min(range.endIndex ?? total, total))
        case .fromStartIndex: return (range.startIndex ?? 0, total)
        default: return (0, total)  // ALL
        }
    }
}

// MARK: - Shape properties

extension GSlidesEditor {
    static func updateShapeProperties(_ r: UpdateShapePropertiesRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let patch = r.shapeProperties else {
            throw GSlidesEditError.invalidRequest("updateShapeProperties")
        }
        let fields = r.fields ?? "*"
        var thrown: Error?
        try mutateElement(id, in: &p) { element in
            guard var shape = element.shape else { return }
            do { shape.shapeProperties = try FieldMask.merge(base: shape.shapeProperties, patch: patch, fields: fields) }
            catch { thrown = error }
            element.shape = shape
        }
        if let thrown { throw thrown }
    }
}
