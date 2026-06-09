import Foundation

/// Intent-level edit vocabulary — the editing counterpart of `SemanticDeck`. An agent refines a
/// deck by emitting these (referencing elements by stable `objectId`), NOT by hand-writing the 44
/// batchUpdate request types: that would blow up input tokens and expose wire detail. `EditExpander`
/// lowers each intent to spec-faithful `Request`s, exactly as `DeckExpander` lowers a `SemanticDeck`.
public struct SemanticEditBatch: Codable, Equatable, Sendable {
    public var edits: [SemanticEdit]
    public init(edits: [SemanticEdit]) { self.edits = edits }
}

/// One edit. A tagged record (an `op` plus the fields that op uses) rather than a Swift enum with
/// associated values, so it JSON-Schemas cleanly and decodes from a flat LLM tool payload.
public struct SemanticEdit: Codable, Equatable, Sendable {
    public enum Op: String, Codable, Sendable {
        case move      // nudge an element by (dxEmu, dyEmu), relative to its current position
        case setText   // replace an element's entire text
        case restyle   // change text style (only the provided attributes)
        case delete    // remove an element (or a whole slide)
        case duplicate // copy an element
        case order     // change z-order
    }

    public var op: Op
    public var id: String

    public var dxEmu: Double?       // move
    public var dyEmu: Double?       // move
    public var text: String?        // setText
    public var bold: Bool?          // restyle
    public var italic: Bool?        // restyle
    public var underline: Bool?     // restyle
    public var colorHex: String?    // restyle (#RRGGBB)
    public var fontSizePt: Double?  // restyle
    public var newId: String?       // duplicate
    public var order: ZOrder?       // order

    public init(
        op: Op, id: String,
        dxEmu: Double? = nil, dyEmu: Double? = nil,
        text: String? = nil,
        bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil,
        colorHex: String? = nil, fontSizePt: Double? = nil,
        newId: String? = nil, order: ZOrder? = nil
    ) {
        self.op = op; self.id = id
        self.dxEmu = dxEmu; self.dyEmu = dyEmu
        self.text = text
        self.bold = bold; self.italic = italic; self.underline = underline
        self.colorHex = colorHex; self.fontSizePt = fontSizePt
        self.newId = newId; self.order = order
    }

    public enum ZOrder: String, Codable, Sendable { case front, back, forward, backward }
}
