import A2ACore
import Foundation
import GSlidesAssembly
import GSlidesSchema
import StructuredDataCore

/// Metadata vocabulary identifying a gslides artifact and declaring its payload schema —
/// the spec-sanctioned extension point (artifact metadata + DataPart), nothing custom on the wire.
public enum GSlidesA2AVocabulary {
    public static let schemaKey = "gslides.schema"
    public static let schemaURI = "https://github.com/no-problem-dev/swift-google-slides-view/schema/v1"
    public static let mediaType = "application/json"
}

public enum GSlidesA2AError: Error, Hashable {
    case notAGSlidesArtifact
    case noDataPart
}

public enum GSlidesArtifactCoding {
    // MARK: Sender side

    /// Envelope event: full presentation, replaces any prior state (append == false).
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
            artifact: try artifact(id: artifactId, payload: presentation),
            append: false,
            lastChunk: lastChunk
        )
    }

    /// Slide event: a single page appended to the artifact (append == true).
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
            artifact: try artifact(id: artifactId, payload: page),
            append: true,
            lastChunk: lastChunk
        )
    }

    // MARK: Receiver side

    public static func isGSlides(_ artifact: Artifact) -> Bool {
        artifact.metadata?[GSlidesA2AVocabulary.schemaKey]?.stringValue == GSlidesA2AVocabulary.schemaURI
    }

    /// Assembly chunks carried by an event — one per data part.
    /// Empty for artifacts that are not gslides (callers just skip them).
    public static func chunks(from event: TaskArtifactUpdateEvent) throws -> [GSlidesChunk] {
        guard isGSlides(event.artifact) else { return [] }
        let payloads = try dataPayloads(of: event.artifact)
        guard !payloads.isEmpty else { throw GSlidesA2AError.noDataPart }
        return payloads.enumerated().map { index, payload in
            GSlidesChunk(
                payload: payload,
                append: event.append,
                lastChunk: event.lastChunk && index == payloads.count - 1
            )
        }
    }

    /// Decodes a complete (non-streamed) gslides artifact.
    public static func presentation(from artifact: Artifact) throws -> Presentation {
        guard isGSlides(artifact) else { throw GSlidesA2AError.notAGSlidesArtifact }
        guard let payload = try dataPayloads(of: artifact).first else {
            throw GSlidesA2AError.noDataPart
        }
        return try JSONDecoder().decode(Presentation.self, from: payload)
    }

    // MARK: Artifact builders (for servers emitting via their own TaskUpdater / event queue)

    /// Envelope artifact: the full presentation as one DataPart.
    public static func envelopeArtifact(id: ArtifactID, presentation: Presentation) throws -> Artifact {
        try artifact(id: id, payload: presentation)
    }

    /// Single-slide artifact for append events.
    public static func slideArtifact(id: ArtifactID, page: Page) throws -> Artifact {
        try artifact(id: id, payload: page)
    }

    // MARK: Coding helpers

    static func artifact(id: ArtifactID, payload: some Encodable) throws -> Artifact {
        let data = try JSONEncoder().encode(payload)
        let value = try JSONDecoder().decode(StructuredValue.self, from: data)
        return Artifact(
            artifactId: id,
            parts: [.data(value, mediaType: GSlidesA2AVocabulary.mediaType)],
            metadata: [GSlidesA2AVocabulary.schemaKey: .string(GSlidesA2AVocabulary.schemaURI)]
        )
    }

    static func dataPayloads(of artifact: Artifact) throws -> [Data] {
        try artifact.parts.compactMap { part in
            guard case .data(let value) = part.content else { return nil }
            return try JSONEncoder().encode(value)
        }
    }
}

/// Stream-level assembler: feed every TaskArtifactUpdateEvent of an A2A stream,
/// it locks onto the first gslides artifact and ignores everything else.
public struct GSlidesArtifactAssembler: Sendable {
    public private(set) var artifactId: ArtifactID?
    public private(set) var assembler = GSlidesAssembler()

    public var presentation: Presentation? { assembler.presentation }
    public var isComplete: Bool { assembler.isComplete }

    public init() {}

    /// Returns true if the event belonged to the tracked gslides artifact.
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
