import Foundation
import GSlidesRequests
import GSlidesSchema

/// Lowers intent-level `SemanticEdit`s to spec-faithful batchUpdate `Request`s — the editing twin
/// of `DeckExpander`. The agent stays in intent space (move/setText/restyle/…); the wire and the
/// reducer see only official requests, so nothing downstream depends on this convenience vocabulary.
public enum EditExpander {
    public static func expand(_ batch: SemanticEditBatch) -> [Request] {
        batch.edits.flatMap(requests(for:))
    }

    static func requests(for edit: SemanticEdit) -> [Request] {
        switch edit.op {
        case .move:
            let t = GSlidesSchema.AffineTransform(
                scaleX: 1, scaleY: 1,
                translateX: edit.dxEmu ?? 0, translateY: edit.dyEmu ?? 0, unit: .emu)
            return [.updatePageElementTransform(UpdatePageElementTransformRequest(
                objectId: edit.id, transform: t, applyMode: .relative))]

        case .setText:
            // Replace the element's whole text: clear it, then insert the new string.
            return [
                Request(deleteText: DeleteTextRequest(objectId: edit.id, textRange: Range(type: .all))),
                Request(insertText: InsertTextRequest(objectId: edit.id, text: edit.text ?? "", insertionIndex: 0)),
            ]

        case .restyle:
            var style = TextStyle()
            var fields: [String] = []
            if let bold = edit.bold { style.bold = bold; fields.append("bold") }
            if let italic = edit.italic { style.italic = italic; fields.append("italic") }
            if let underline = edit.underline { style.underline = underline; fields.append("underline") }
            if let hex = edit.colorHex, let rgb = Self.rgb(hex) {
                style.foregroundColor = OptionalColor(opaqueColor: OpaqueColor(rgbColor: rgb))
                fields.append("foregroundColor")
            }
            if let size = edit.fontSizePt {
                style.fontSize = Dimension(magnitude: size, unit: .pt)
                fields.append("fontSize")
            }
            guard !fields.isEmpty else { return [] }
            return [.updateTextStyle(UpdateTextStyleRequest(
                objectId: edit.id, style: style, textRange: Range(type: .all), fields: fields.joined(separator: ",")))]

        case .delete:
            return [.deleteObject(DeleteObjectRequest(objectId: edit.id))]

        case .duplicate:
            let map = edit.newId.map { [edit.id: $0] }
            return [.init(duplicateObject: DuplicateObjectRequest(objectId: edit.id, objectIds: map))]

        case .order:
            let op: UpdatePageElementsZOrderRequestOperation = switch edit.order ?? .front {
            case .front: .bringToFront
            case .back: .sendToBack
            case .forward: .bringForward
            case .backward: .sendBackward
            }
            return [.init(updatePageElementsZOrder: UpdatePageElementsZOrderRequest(
                pageElementObjectIds: [edit.id], operation: op))]
        }
    }

    /// `#RRGGBB` (or `RRGGBB`) → normalized RgbColor; nil if malformed.
    static func rgb(_ hex: String) -> RgbColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        return RgbColor(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}

public extension Presentation {
    /// Apply intent-level edits (lowered to requests, then run through the reducer).
    func applying(_ batch: SemanticEditBatch) throws -> Presentation {
        try applying(EditExpander.expand(batch))
    }
}
