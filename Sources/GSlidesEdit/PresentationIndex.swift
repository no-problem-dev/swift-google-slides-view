import Foundation
import GSlidesRequests
import GSlidesSchema

/// `Presentation` の読み取り専用インデックス。preflight パスごとに 1 回構築される：
/// 存在するオブジェクト ID（スライド＋要素、共有名前空間。catalog: object-id-uniqueness）、
/// 各要素の現在のトランスフォーム / サイズ、ページサイズを持つ。
/// バリデーターがリクエストごとにツリーを再走査せずに存在確認とページ境界の問いに答えるために必要なすべて。
struct PresentationIndex {
    private(set) var slideIds: Set<String> = []
    private(set) var elementIds: Set<String> = []
    private var elements: [String: PageElement] = [:]
    /// EMU 単位のページサイズ。プレゼンテーションが宣言している場合のみ（インメモリプレゼンテーションは宣言しないことが多い）。
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
    /// 共有名前空間：スライドまたは要素のいずれかが使用する ID は専有済み。
    func exists(_ id: String) -> Bool { elementIds.contains(id) || slideIds.contains(id) }

    /// `mode` で `transform` を適用した後に要素が占める EMU バウンディングボックス。
    /// 左上は平行移動成分から、広さは要素の固有サイズにトランスフォームのスケールをかけた値から算出する。
    /// 要素が未知の場合は nil を返す。`translate` は左上角（catalog: page-bounds）なので
    /// ボックスは [tx, tx+w] × [ty, ty+h]。
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

/// スライド上の軸平行 EMU バウンディングボックス。
struct Box: Equatable {
    var x: Double, y: Double, w: Double, h: Double

    /// ページ矩形 [0,width] × [0,height] と全く重ならない — 要素がスライド完全外にある。
    func isEntirelyOutside(width: Double, height: Double) -> Bool {
        x + w <= 0 || x >= width || y + h <= 0 || y >= height
    }

    func describe() -> String {
        "box x=\(Int(x)) y=\(Int(y)) w=\(Int(w)) h=\(Int(h))"
    }
}
