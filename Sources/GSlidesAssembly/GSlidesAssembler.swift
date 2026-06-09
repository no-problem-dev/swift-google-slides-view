import Foundation
import GSlidesEdit
import GSlidesRequests
import GSlidesSchema

/// Transport-agnostic chunk primitive. Adapters (e.g. GSlidesA2A) map their
/// protocol's stream events onto this — the reducer never sees protocol types.
public struct GSlidesChunk: Equatable, Sendable {
    /// What the payload carries — the three presentation-stream shapes.
    public enum Kind: String, Equatable, Sendable {
        case envelope     // a full `Presentation` — replaces the state
        case slide        // a single `Page` — appended to `slides`
        case batchUpdate  // a `BatchUpdatePresentationRequest` — applied to the current state
    }

    public var payload: Data
    public var kind: Kind
    public var lastChunk: Bool

    /// Wire append-semantics: a chunk builds on prior state unless it's a full envelope.
    public var append: Bool { kind != .envelope }

    public init(payload: Data, kind: Kind = .envelope, lastChunk: Bool = false) {
        self.payload = payload
        self.kind = kind
        self.lastChunk = lastChunk
    }

    /// Back-compat: `append == false` → envelope, `append == true` → slide.
    public init(payload: Data, append: Bool, lastChunk: Bool = false) {
        self.init(payload: payload, kind: append ? .slide : .envelope, lastChunk: lastChunk)
    }
}

public enum GSlidesAssemblyError: Error, Hashable {
    case invalidPayload(String)
    case chunkAfterCompletion
}

/// Pure reducer over chunk sequences:
/// - `.envelope`: payload is a full `Presentation` — replaces the state.
/// - `.slide`: payload is a single `Page` — appended to `slides`. A slide before any
///   envelope creates an implicit empty presentation, so slide-led streams still assemble.
/// - `.batchUpdate`: payload is a `BatchUpdatePresentationRequest` — applied to the current
///   state via the local reducer (element-level live edits without resending the presentation).
/// - `lastChunk == true`: completes the stream; further chunks are an error.
/// A throwing apply leaves the state unchanged.
public struct GSlidesAssembler: Equatable, Sendable {
    public private(set) var presentation: Presentation?
    public private(set) var isComplete: Bool

    public init() {
        presentation = nil
        isComplete = false
    }

    public mutating func apply(_ chunk: GSlidesChunk) throws {
        // envelope/slide are stream-continuation chunks — rejected once the stream completed.
        // batchUpdate is a post-stream live edit (an agent tweaking a finished presentation) — always
        // allowed, otherwise the diff is silently dropped and the presentation never visibly updates.
        if chunk.kind != .batchUpdate, isComplete {
            throw GSlidesAssemblyError.chunkAfterCompletion
        }
        let decoder = JSONDecoder()
        switch chunk.kind {
        case .envelope:
            do {
                presentation = try decoder.decode(Presentation.self, from: chunk.payload)
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
        case .slide:
            let page: Page
            do {
                page = try decoder.decode(Page.self, from: chunk.payload)
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
            var current = presentation ?? Presentation()
            current.slides = (current.slides ?? []) + [page]
            presentation = current
        case .batchUpdate:
            let batch: BatchUpdatePresentationRequest
            do {
                batch = try decoder.decode(BatchUpdatePresentationRequest.self, from: chunk.payload)
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
            // Best-effort: a single bad edit (stale objectId, unsupported op) must not drop the whole
            // batch — apply what's valid so the presentation still visibly updates.
            presentation = (presentation ?? Presentation()).applyingLenient(batch.requests ?? []).presentation
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
