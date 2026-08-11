import Foundation
import GSlidesSchema

/// One element described well enough for an editing agent to decide whether to change it.
///
/// The stable `objectId` is what a batchUpdate request references; the rest is context — kind,
/// label, current text and EMU bounding box. This is the read half of the edit loop: an agent
/// inspects, then emits requests.
public struct PresentationElementDescriptor: Codable, Equatable, Sendable {
    public var objectId: String
    public var slideIndex: Int
    public var kind: String              // text | image | line | table | shape | group | other
    public var label: String?            // placeholder role or shape type
    public var text: String?             // current text, runs joined and truncated; nil when empty
    /// Position and size in EMU, normalized from whatever unit the element declared.
    ///
    /// nil where the element carries no transform or size — an unresolved placeholder, typically.
    public var xEmu: Double?
    public var yEmu: Double?
    public var widthEmu: Double?
    public var heightEmu: Double?
}

/// A whole presentation reduced to its editable surface — what an agent sees before it edits.
///
/// Only slides are walked; layouts, masters and notes pages are not described. Elements are flat and
/// carry their slide index rather than being nested under it.
public struct PresentationSnapshot: Codable, Equatable, Sendable {
    public var presentationTitle: String?
    public var slideCount: Int
    public var slideIds: [String]
    public var elements: [PresentationElementDescriptor]
}

/// Renders a presentation as an agent-facing snapshot. Pure, and tied to no particular LLM: a host
/// wraps it as an `inspect_presentation` tool while this package owns the projection.
public enum GSlidesPresentationInspector {
    /// The snapshot of a presentation.
    ///
    /// - Parameters:
    ///   - presentation: The presentation to describe. Only its slides are walked.
    ///   - textLimit: Maximum characters of element text to include; longer text is truncated with
    ///     an ellipsis, so the result is a preview, not a source of truth for editing indices.
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

    /// The snapshot encoded as JSON with sorted keys, so the same presentation always produces the
    /// same bytes and the result is safe to cache or diff.
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

    /// Normalizes a magnitude to EMU (1 pt = 12,700 EMU). EMU and an unspecified unit pass through.
    static func emu(_ magnitude: Double?, unit: GSlidesSchema.Unit?) -> Double? {
        guard let magnitude else { return nil }
        return unit == .pt ? magnitude * 12700 : magnitude
    }

    static func truncate(_ string: String, _ limit: Int) -> String {
        string.count <= limit ? string : String(string.prefix(limit)) + "…"
    }
}
