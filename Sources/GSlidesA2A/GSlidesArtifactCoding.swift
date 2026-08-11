import A2ACore
import Foundation
import GSlidesAssembly
import GSlidesRequests
import GSlidesSchema
import StructuredDataCore

/// The metadata keys that identify a gslides artifact and declare its payload schema.
///
/// Both live in the extension points the A2A spec already allows — artifact metadata and DataPart —
/// so nothing custom appears on the wire.
public enum GSlidesA2AVocabulary {
    /// Metadata key whose value marks an artifact as a gslides stream.
    public static let schemaKey = "gslides.schema"
    /// The value `schemaKey` must hold. A receiver ignores any artifact that does not carry it.
    public static let schemaURI = "https://github.com/no-problem-dev/swift-google-slides-view/schema/v1"
    public static let mediaType = "application/json"
    /// Metadata key declaring the payload shape: envelope, slide or batchUpdate.
    ///
    /// Optional. When absent the receiver infers the kind from the event's `append` flag, which
    /// cannot distinguish a batch update from a slide.
    public static let kindKey = "gslides.kind"
}

/// Why a gslides artifact could not be read.
public enum GSlidesA2AError: Error, Hashable {
    /// The artifact carries no gslides schema marker, so it belongs to some other producer.
    case notAGSlidesArtifact
    /// The artifact is marked as gslides but carries no DataPart to decode.
    case noDataPart
}

/// Encodes presentations into A2A artifact events and decodes them back into assembly chunks.
public enum GSlidesArtifactCoding {
    // MARK: Sender side

    /// An event carrying a whole presentation, which replaces whatever the receiver had.
    ///
    /// Sent with `append: false`.
    ///
    /// - Throws: The encoding error if the presentation cannot be written as JSON.
    public static func envelopeEvent(
        taskId: TaskID,
        contextId: ContextID,
        artifactId: ArtifactID,
        presentation: Presentation,
        lastChunk: Bool = false
    ) throws -> TaskArtifactUpdateEvent {
        TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: try artifact(id: artifactId, kind: .envelope, payload: presentation),
            append: false,
            lastChunk: lastChunk
        )
    }

    /// An event carrying one page, appended to what the receiver already has.
    ///
    /// Sent with `append: true`. A slide may precede any envelope; the receiver starts an empty
    /// presentation to append to.
    public static func slideEvent(
        taskId: TaskID,
        contextId: ContextID,
        artifactId: ArtifactID,
        page: Page,
        lastChunk: Bool = false
    ) throws -> TaskArtifactUpdateEvent {
        TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: try artifact(id: artifactId, kind: .slide, payload: page),
            append: true,
            lastChunk: lastChunk
        )
    }

    /// An event carrying element-level edits to apply to the receiver's current presentation.
    ///
    /// Lets an agent stream "move element X, restyle Y" without resending the deck. Sent with
    /// `append: true`, and the receiver applies the batch atomically — all of it or none.
    ///
    /// A receiver older than the `gslides.kind` metadata key will read this as a slide and fail to
    /// decode it.
    public static func batchUpdateEvent(
        taskId: TaskID,
        contextId: ContextID,
        artifactId: ArtifactID,
        requests: [Request],
        lastChunk: Bool = false
    ) throws -> TaskArtifactUpdateEvent {
        TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: try artifact(id: artifactId, kind: .batchUpdate, payload: BatchUpdatePresentationRequest(requests: requests)),
            append: true,
            lastChunk: lastChunk
        )
    }

    // MARK: Receiver side

    /// Whether the artifact carries this package's schema marker.
    ///
    /// The filter a receiver applies before doing anything else, so artifacts from other producers
    /// on the same stream pass through untouched.
    public static func isGSlides(_ artifact: Artifact) -> Bool {
        artifact.metadata?[GSlidesA2AVocabulary.schemaKey]?.stringValue == GSlidesA2AVocabulary.schemaURI
    }

    /// The assembly chunks an event carries, one per DataPart.
    ///
    /// Only the last chunk inherits the event's `lastChunk` flag, so a multi-part event does not
    /// close the stream early.
    ///
    /// - Returns: An empty array for a non-gslides artifact, which callers skip.
    /// - Throws: ``GSlidesA2AError/noDataPart`` when a gslides artifact carries no data.
    public static func chunks(from event: TaskArtifactUpdateEvent) throws -> [GSlidesChunk] {
        guard isGSlides(event.artifact) else { return [] }
        let payloads = try dataPayloads(of: event.artifact)
        guard !payloads.isEmpty else { throw GSlidesA2AError.noDataPart }
        let kind = chunkKind(of: event)
        return payloads.enumerated().map { index, payload in
            GSlidesChunk(
                payload: payload,
                kind: kind,
                lastChunk: event.lastChunk && index == payloads.count - 1
            )
        }
    }

    /// The payload kind the artifact declares.
    ///
    /// Falls back to inferring from the `append` flag when the metadata key is missing or holds an
    /// unrecognized value, which reads any appended payload as a slide.
    static func chunkKind(of event: TaskArtifactUpdateEvent) -> GSlidesChunk.Kind {
        if let raw = event.artifact.metadata?[GSlidesA2AVocabulary.kindKey]?.stringValue,
           let kind = GSlidesChunk.Kind(rawValue: raw) {
            return kind
        }
        return event.append ? .slide : .envelope
    }

    /// Decodes a complete, non-streamed gslides artifact.
    ///
    /// Reads the first DataPart only, and assumes it holds a whole presentation — it does not check
    /// the declared kind, so pointing it at a slide or batch-update artifact fails to decode.
    ///
    /// - Throws: ``GSlidesA2AError/notAGSlidesArtifact`` or ``GSlidesA2AError/noDataPart``.
    public static func presentation(from artifact: Artifact) throws -> Presentation {
        guard isGSlides(artifact) else { throw GSlidesA2AError.notAGSlidesArtifact }
        guard let payload = try dataPayloads(of: artifact).first else {
            throw GSlidesA2AError.noDataPart
        }
        return try JSONDecoder().decode(Presentation.self, from: payload)
    }

    // MARK: Artifact builders (for servers emitting via their own TaskUpdater / event queue)

    /// An artifact holding a whole presentation as a single DataPart.
    ///
    /// For servers that emit through their own TaskUpdater rather than the event helpers above.
    public static func envelopeArtifact(id: ArtifactID, presentation: Presentation) throws -> Artifact {
        try artifact(id: id, kind: .envelope, payload: presentation)
    }

    /// An artifact holding one page. Emit it with `append: true`.
    public static func slideArtifact(id: ArtifactID, page: Page) throws -> Artifact {
        try artifact(id: id, kind: .slide, payload: page)
    }

    /// An artifact holding element-level edits. Emit it with `append: true`.
    public static func batchUpdateArtifact(id: ArtifactID, requests: [Request]) throws -> Artifact {
        try artifact(id: id, kind: .batchUpdate, payload: BatchUpdatePresentationRequest(requests: requests))
    }

    // MARK: Coding helpers

    static func artifact(id: ArtifactID, kind: GSlidesChunk.Kind, payload: some Encodable) throws -> Artifact {
        let data = try JSONEncoder().encode(payload)
        let value = try JSONDecoder().decode(StructuredValue.self, from: data)
        return Artifact(
            artifactId: id,
            parts: [.data(value, mediaType: GSlidesA2AVocabulary.mediaType)],
            metadata: [
                GSlidesA2AVocabulary.schemaKey: .string(GSlidesA2AVocabulary.schemaURI),
                GSlidesA2AVocabulary.kindKey: .string(kind.rawValue),
            ]
        )
    }

    static func dataPayloads(of artifact: Artifact) throws -> [Data] {
        try artifact.parts.compactMap { part in
            guard case .data(let value) = part.content else { return nil }
            return try JSONEncoder().encode(value)
        }
    }
}

/// A stream-level assembler for an A2A event stream.
///
/// Feed it every `TaskArtifactUpdateEvent`; it locks onto the first gslides artifact it sees and
/// ignores everything else.
///
/// Locking onto one artifact means a second gslides deck on the same stream is dropped silently.
public struct GSlidesArtifactAssembler: Sendable {
    /// The artifact this assembler locked onto, or nil until the first gslides event arrives.
    public private(set) var artifactId: ArtifactID?
    public private(set) var assembler = GSlidesAssembler()

    /// The presentation assembled so far, or nil before the first chunk.
    public var presentation: Presentation? { assembler.presentation }
    /// Whether a `lastChunk` has closed the stream.
    public var isComplete: Bool { assembler.isComplete }

    public init() {}

    /// Folds an event into the presentation.
    ///
    /// - Returns: Whether the event belonged to the tracked gslides artifact. False means it was
    ///   ignored — a different producer's artifact, or a second gslides artifact on the same stream.
    /// - Throws: Anything the chunk decoder or the underlying assembler throws.
    @discardableResult
    public mutating func apply(_ event: TaskArtifactUpdateEvent) throws -> Bool {
        guard GSlidesArtifactCoding.isGSlides(event.artifact) else { return false }
        if let artifactId, artifactId != event.artifact.artifactId { return false }
        artifactId = event.artifact.artifactId
        for chunk in try GSlidesArtifactCoding.chunks(from: event) {
            try assembler.apply(chunk)
        }
        return true
    }
}
