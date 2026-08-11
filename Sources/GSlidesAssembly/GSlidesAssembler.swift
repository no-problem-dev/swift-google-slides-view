import Foundation
import GSlidesEdit
import GSlidesRequests
import GSlidesSchema

/// One piece of a presentation stream, independent of the transport that delivered it.
///
/// An adapter — `GSlidesA2A`, for instance — maps its protocol's stream events onto this, so the
/// reducer never sees a protocol type.
public struct GSlidesChunk: Equatable, Sendable {
    /// What the payload holds — the three shapes a presentation stream carries.
    public enum Kind: String, Equatable, Sendable {
        case envelope     // a full `Presentation` — replaces the state
        case slide        // a single `Page` — appended to `slides`
        case batchUpdate  // a `BatchUpdatePresentationRequest` — applied to the current state
    }

    public var payload: Data
    public var kind: Kind
    public var lastChunk: Bool

    /// The wire's append semantics: every kind but `.envelope` builds on the state before it.
    public var append: Bool { kind != .envelope }

    public init(payload: Data, kind: Kind = .envelope, lastChunk: Bool = false) {
        self.payload = payload
        self.kind = kind
        self.lastChunk = lastChunk
    }

    /// Creates a chunk from a wire that only distinguishes replace from append: false gives
    /// `.envelope`, true gives `.slide`.
    ///
    /// Cannot produce a `.batchUpdate` chunk — use the kind-taking initializer for that.
    public init(payload: Data, append: Bool, lastChunk: Bool = false) {
        self.init(payload: payload, kind: append ? .slide : .envelope, lastChunk: lastChunk)
    }
}

/// Why a chunk could not be folded into the presentation.
public enum GSlidesAssemblyError: Error, Hashable {
    /// The payload did not decode as its kind, or a `.batchUpdate` batch was rejected.
    ///
    /// The associated string is a description of the underlying error, not the error itself, so the
    /// original `BatchUpdateError` and its field violations are not recoverable from here.
    case invalidPayload(String)
    /// An `.envelope` or `.slide` chunk arrived after `lastChunk` sealed the stream.
    case chunkAfterCompletion
}

/// A pure reducer that folds a sequence of chunks into a `Presentation`.
///
/// - `.envelope` replaces the state with the decoded presentation.
/// - `.slide` appends a page. Arriving before any envelope creates an empty presentation to append
///   to, so a slides-first stream assembles cleanly.
/// - `.batchUpdate` applies a batch to the current state through the local reducer — element-level
///   live edits without resending the deck.
///
/// A chunk with `lastChunk == true` seals the stream. Later `.envelope` and `.slide` chunks are
/// rejected; `.batchUpdate` chunks are still accepted, because an agent adjusting a finished
/// presentation should not be silently ignored.
///
/// Every failure leaves the state as it was — a throwing `apply` never half-applies a chunk.
public struct GSlidesAssembler: Equatable, Sendable {
    /// The presentation built so far, or nil until the first chunk lands.
    public private(set) var presentation: Presentation?
    /// Whether a `lastChunk` has been seen. Further slides are refused; batch updates are not.
    public private(set) var isComplete: Bool

    public init() {
        presentation = nil
        isComplete = false
    }

    /// Folds one chunk into the state.
    ///
    /// - Throws: ``GSlidesAssemblyError/invalidPayload(_:)`` when the payload does not decode as its
    ///   kind, or when a batch update is rejected — batches are atomic, so a bad one leaves the
    ///   presentation untouched rather than partly edited.
    ///   ``GSlidesAssemblyError/chunkAfterCompletion`` for a slide or envelope after the stream closed.
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
            // Atomic, exactly like the real API: a batch either applies in full or not at all. An
            // invalid batch (stale objectId, off-page move, unsupported op) surfaces as an assembly
            // error instead of silently applying a partial, inconsistent edit.
            do {
                presentation = try (presentation ?? Presentation()).applying(batch.requests ?? [])
            } catch {
                throw GSlidesAssemblyError.invalidPayload(String(describing: error))
            }
        }
        if chunk.lastChunk {
            isComplete = true
        }
    }

    /// Folds a whole sequence of chunks and returns the finished presentation.
    ///
    /// Does not require the sequence to end in a `lastChunk`, so a truncated stream yields whatever
    /// was assembled rather than an error.
    ///
    /// - Throws: ``GSlidesAssemblyError/invalidPayload(_:)`` if the sequence is empty or produced no
    ///   presentation, plus anything `apply(_:)` throws.
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
