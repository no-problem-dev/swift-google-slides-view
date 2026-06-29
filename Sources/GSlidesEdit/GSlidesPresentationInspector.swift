import Foundation
import GSlidesSchema

/// 編集エージェント向けのアドレス可能な 1 要素の記述。変更対象を決定するのに十分なコンテキスト
/// （kind、ラベル、現在のテキスト、EMU バウンディングボックス）を持つ安定した `objectId`。
/// 編集ループの「現在の状態を読む」半分 — エージェントが inspect を呼び出し、
/// その後 batchUpdate リクエストを emit する。
public struct PresentationElementDescriptor: Codable, Equatable, Sendable {
    public var objectId: String
    public var slideIndex: Int
    public var kind: String              // text | image | line | table | shape | group | other
    public var label: String?            // placeholder role or shape type
    public var text: String?             // current text (runs joined), if any
    public var xEmu: Double?
    public var yEmu: Double?
    public var widthEmu: Double?
    public var heightEmu: Double?
}

/// プレゼンテーション全体を編集可能なサーフェスに縮約したもの — エージェントが編集前に見る情報。
public struct PresentationSnapshot: Codable, Equatable, Sendable {
    public var presentationTitle: String?
    public var slideCount: Int
    public var slideIds: [String]
    public var elements: [PresentationElementDescriptor]
}

/// `Presentation` をエージェント向けスナップショットにレンダリングする。純粋かつ LLM 非依存：
/// ホストが `inspect_presentation` ツールとしてラップし、パッケージが射影（objectId ↔ 要素の種別）を所有する。
public enum GSlidesPresentationInspector {
    public static func snapshot(_ presentation: Presentation, textLimit: Int = 120) -> PresentationSnapshot {
        let slides = presentation.slides ?? []
        var elements: [PresentationElementDescriptor] = []
        for (index, slide) in slides.enumerated() {
            for element in slide.pageElements ?? [] {
                elements.append(descriptor(element, slideIndex: index, textLimit: textLimit))
            }
        }
        return PresentationSnapshot(
            presentationTitle: presentation.title,
            slideCount: slides.count,
            slideIds: slides.map(\.objectId),
            elements: elements)
    }

    public static func snapshotJSON(_ presentation: Presentation, textLimit: Int = 120) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(snapshot(presentation, textLimit: textLimit))
    }

    static func descriptor(_ element: PageElement, slideIndex: Int, textLimit: Int) -> PresentationElementDescriptor {
        PresentationElementDescriptor(
            objectId: element.objectId,
            slideIndex: slideIndex,
            kind: kind(of: element),
            label: label(of: element),
            text: text(of: element).map { truncate($0, textLimit) },
            xEmu: emu(element.transform?.translateX, unit: element.transform?.unit),
            yEmu: emu(element.transform?.translateY, unit: element.transform?.unit),
            widthEmu: emu(element.size?.width?.magnitude, unit: element.size?.width?.unit),
            heightEmu: emu(element.size?.height?.magnitude, unit: element.size?.height?.unit))
    }

    static func kind(of element: PageElement) -> String {
        switch element.kind {
        case .shape: "text"   // shapes are text boxes in this profile's authored presentations
        case .image: "image"
        case .line: "line"
        case .table: "table"
        case .elementGroup: "group"
        case .unknown: "other"
        default: "shape"
        }
    }

    static func label(of element: PageElement) -> String? {
        if let placeholder = element.shape?.placeholder?.type { return placeholder.rawValue }
        if let shapeType = element.shape?.shapeType { return shapeType.rawValue }
        switch element.kind {
        case .image: return "PICTURE"
        case .line: return "LINE"
        case .table: return "TABLE"
        default: return nil
        }
    }

    static func text(of element: PageElement) -> String? {
        guard let elements = element.shape?.text?.textElements else { return nil }
        let joined = elements.compactMap { $0.textRun?.content }.joined()
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// マグニチュードを EMU に正規化する（1pt = 12700 EMU）。既に EMU または単位なしの場合はそのまま返す。
    static func emu(_ magnitude: Double?, unit: GSlidesSchema.Unit?) -> Double? {
        guard let magnitude else { return nil }
        return unit == .pt ? magnitude * 12700 : magnitude
    }

    static func truncate(_ string: String, _ limit: Int) -> String {
        string.count <= limit ? string : String(string.prefix(limit)) + "…"
    }
}
