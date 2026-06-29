import Foundation
import GSlidesRequests
import GSlidesSchema

public extension Presentation {
    /// batchUpdate リクエストのシーケンスをこのプレゼンテーションに適用し、新しい値を返す。
    /// 純粋（I/O なし、Google 依存なし）：公式 `Request` ボキャブラリーをローカルで実行する。
    ///
    /// **実際の API とまったく同じアトミック性** — 「いずれかのリクエストが無効な場合、リクエスト
    /// 全体が失敗し何も適用されない」（catalog: batch-atomicity）。リデューサーはコピー上で動作し、
    /// 完全適用済みの結果のみを返す。失敗すると `BatchUpdateError` をスローし `self` は変更されない。
    /// （すべてのバイオレーションを収集するリッチな事前検証は `PreflightValidator` にあり、
    /// このリデューサーは実行＋最終安全網の役割を持つ。）
    ///
    /// テキスト編集のインデックス規約：位置は `textRun` のコンテンツのみをカウントし、
    /// 段落マーカーおよびオートテキストはゼロ幅 — リデューサー固有の内部一貫した規約。
    func applying(_ requests: [Request]) throws -> Presentation {
        var p = self
        for (i, request) in requests.enumerated() {
            do { try GSlidesEditor.apply(request, to: &p) }
            catch let violation as FieldViolation {
                throw BatchUpdateError.invalidArgument([violation.prefixed(byRequestIndex: i)])
            }
        }
        return p
    }
}

/// ローカル `batchUpdate` エグゼキュータ。凍結した Schema+Requests ミラー上に位置し、
/// 上位のすべて（A2A 差分デリバリー、エージェント編集ループ）がこの 1 つのエントリポイントを通じて
/// プレゼンテーションを駆動する。
public enum GSlidesEditor {
    /// ローカルリデューサーが実際に実行するオペレーション — `PreflightValidator` が使う「サポート済み」
    /// の SSOT。下の `apply(_:to:)` スイッチをミラーし、テストの `supportedOperationsCoverSwitch`
    /// が 2 つを同期させる。
    public static let supportedOperations: Set<String> = [
        "deleteObject", "updatePageElementTransform", "updatePageElementsZOrder", "duplicateObject",
        "createSlide", "replaceAllText", "insertText", "deleteText", "updateTextStyle",
        "updateShapeProperties",
    ]

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
        case .other:
            throw FieldViolation(field: "", description: "Request has no operation set.", reason: .emptyRequest)
        default:
            throw FieldViolation(field: label(request),
                description: "Operation '\(label(request))' is not supported by the local edit engine.",
                reason: .unsupportedOperation)
        }
    }

    // MARK: Reducer-local violations (safety net; PreflightValidator reports these up front)

    static func notFound(_ id: String) -> FieldViolation {
        FieldViolation(field: "objectId", description: "No object with objectId '\(id)' exists.",
                       reason: .objectNotFound)
    }
    static func missing(_ field: String) -> FieldViolation {
        FieldViolation(field: field, description: "Required field '\(field)' is missing.",
                       reason: .requiredFieldMissing)
    }
    static func unsupported(_ what: String) -> FieldViolation {
        FieldViolation(field: what, description: "\(what) is not supported by the local edit engine.",
                       reason: .unsupportedOperation)
    }

    /// リクエストのセットメンバーのワイヤーフィールド名（診断用）— データ駆動で、44 ケースのスイッチ不要。
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
    /// id でどこにあっても（グループに再帰して）要素を見つけ、その場で変更する。
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
        throw notFound(id)
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
        guard let id = r.objectId else { throw missing("deleteObject.objectId") }
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
        throw notFound(id)
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
        guard let id = r.objectId else { throw missing("duplicateObject.objectId") }
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
        throw notFound(id)
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
        throw notFound(ids.joined(separator: ","))
    }
}

// MARK: - Geometry

extension GSlidesEditor {
    static func updateTransform(_ r: UpdatePageElementTransformRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let t = r.transform else {
            throw missing("updatePageElementTransform")
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

    /// 2×3 アフィン連結：`existing` の上に `update` を適用した結果（existing が先）。
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

    /// (sx, sy, hx, hy, tx, ty) — nil はアイデンティティ成分をデフォルトとする。
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

    /// すべてのシェイプのテキストラン（グループに再帰）を走査し、各ランのコンテンツを変換する。
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
            throw missing("insertText")
        }
        if r.cellLocation != nil { throw unsupported("insertText(table cell)") }
        try editText(id, in: &p) { els in
            splice(&els, at: r.insertionIndex ?? 0, removing: 0, inserting: text)
        }
    }

    static func deleteText(_ r: DeleteTextRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId else { throw missing("deleteText") }
        if r.cellLocation != nil { throw unsupported("deleteText(table cell)") }
        try editText(id, in: &p) { els in
            let (start, end) = resolveRange(r.textRange, total: textLength(els))
            guard end > start else { return }
            splice(&els, at: start, removing: end - start, inserting: "")
        }
    }

    static func updateTextStyle(_ r: UpdateTextStyleRequest, _ p: inout Presentation) throws {
        guard let id = r.objectId, let style = r.style else {
            throw missing("updateTextStyle")
        }
        if r.cellLocation != nil { throw unsupported("updateTextStyle(table cell)") }
        let fields = r.fields ?? ""  // 省略時は FieldMask が patch の存在キーを推論
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

    /// シェイプのテキスト要素をその場で編集し、段落マーカーとコンパクト形式
    /// （1 要素上のマーカー＋ラン）を保持して、フラット化されたインデックスを再導出する。
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

    /// 各ラン保持要素のフラット化された [start,end)。要素順。
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

    /// フラット化された文字オフセットでスプライスし、各文字を元のランエレメントに束縛させたまま保持する
    /// （マーカー保持）。挿入テキストは挿入点のランに合流し、そのスタイルを継承する。
    /// 削除によって空になったラン専用要素は削除し、マーカー付き要素は保持する。
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
            throw missing("updateShapeProperties")
        }
        let fields = r.fields ?? ""  // 省略時は FieldMask が patch の存在キーを推論
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
