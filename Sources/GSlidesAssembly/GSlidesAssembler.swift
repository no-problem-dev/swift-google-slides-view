import Foundation
import GSlidesSchema

/// Transport-agnostic chunk primitive. Adapters (e.g. GSlidesA2A) map their
/// protocol's stream events onto this — the reducer never sees protocol types.
public struct GSlidesChunk: Hashable, Sendable {
    public var payload: Data
    public var append: Bool
    public var lastChunk: Bool

    public init(payload: Data, append: Bool = false, lastChunk: Bool = false) {
        self.payload = payload
        self.append = append
        self.lastChunk = lastChunk
    }
}

public enum GSlidesAssemblyError: Error, Hashable {
    case invalidPayload(String)
    case chunkAfterCompletion
}

/// Pure reducer over chunk sequences:
/// - `append == false`: payload is a full `Presentation` — replaces the state.
/// - `append == true`: payload is a single `Page` — appended to `slides`.
///   An append before any envelope creates an implicit empty presentation,
///   so streams that lead with slides still assemble.
/// - `lastChunk == true`: completes the stream; further chunks are an error.
/// A throwing apply leaves the state unchanged.
public struct GSlidesAssembler: Hashable, Sendable {
    public private(set) var presentation: Presentation?
    public private(set) var isComplete: Bool

    public init() {
        presentation = nil
        isComplete = false
    }

    public mutating func apply(_ chunk: GSlidesChunk) throws {
        guard !isComplete else { throw GSlidesAssemblyError.chunkAfterCompletion }
        let decoder = JSONDecoder()
        if chunk.append {
            let page: Page
            do {
                page = try decoder.decode(Page.self, from: chunk.payload)
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
            var current = presentation ?? Presentation()
            current.slides = (current.slides ?? []) + [page]
            presentation = current
        } else {
            do {
                presentation = try decoder.decode(Presentation.self, from: chunk.payload)
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
        }
        if chunk.lastChunk {
            isComplete = true
        }
    }

    public static func assemble(_ chunks: some Sequence<GSlidesChunk>) throws -> Presentation {
        var assembler = GSlidesAssembler()
        for chunk in chunks {
            try assembler.apply(chunk)
        }
        guard let presentation = assembler.presentation else {
            throw GSlidesAssemblyError.invalidPayload("empty chunk sequence")
        }
        return presentation
    }
}
