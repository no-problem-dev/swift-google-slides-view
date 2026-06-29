import A2ACore
import Foundation
import GSlidesAssembly
import GSlidesRequests
import GSlidesSchema
import StructuredDataCore

/// gslides アーティファクトを識別しペイロードスキーマを宣言するメタデータボキャブラリ —
/// 仕様が認めた拡張ポイント（アーティファクトメタデータ＋DataPart）。ワイヤーにカスタム要素はない。
public enum GSlidesA2AVocabulary {
    public static let schemaKey = "gslides.schema"
    public static let schemaURI = "https://github.com/no-problem-dev/swift-google-slides-view/schema/v1"
    public static let mediaType = "application/json"
    /// ペイロードの形状（envelope / slide / batchUpdate）を宣言する。存在しない場合は `append` から推論。
    public static let kindKey = "gslides.kind"
}

public enum GSlidesA2AError: Error, Hashable {
    case notAGSlidesArtifact
    case noDataPart
}

public enum GSlidesArtifactCoding {
    // MARK: Sender side

    /// エンベロープイベント：完全なプレゼンテーション。以前の状態を置き換える（append == false）。
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

    /// スライドイベント：アーティファクトに追記する単一ページ（append == true）。
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

    /// バッチ更新イベント：現在のプレゼンテーションに適用する要素レベルの編集（append == true）。
    /// エージェントがプレゼンテーション全体を再送せずに「要素 X を移動 / Y を再スタイル」をストリームできる。
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

    public static func isGSlides(_ artifact: Artifact) -> Bool {
        artifact.metadata?[GSlidesA2AVocabulary.schemaKey]?.stringValue == GSlidesA2AVocabulary.schemaURI
    }

    /// イベントが持つアセンブリチャンク — データパートごとに 1 つ。
    /// gslides でないアーティファクトには空（呼び出し元はそのままスキップする）。
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

    /// 宣言されたペイロード kind。kind メタデータが存在する前に emit されたアーティファクトには
    /// レガシーの append フラグ推論にフォールバックする。
    static func chunkKind(of event: TaskArtifactUpdateEvent) -> GSlidesChunk.Kind {
        if let raw = event.artifact.metadata?[GSlidesA2AVocabulary.kindKey]?.stringValue,
           let kind = GSlidesChunk.Kind(rawValue: raw) {
            return kind
        }
        return event.append ? .slide : .envelope
    }

    /// 完全な（ストリームでない）gslides アーティファクトをデコードする。
    public static func presentation(from artifact: Artifact) throws -> Presentation {
        guard isGSlides(artifact) else { throw GSlidesA2AError.notAGSlidesArtifact }
        guard let payload = try dataPayloads(of: artifact).first else {
            throw GSlidesA2AError.noDataPart
        }
        return try JSONDecoder().decode(Presentation.self, from: payload)
    }

    // MARK: Artifact builders (for servers emitting via their own TaskUpdater / event queue)

    /// エンベロープアーティファクト：完全なプレゼンテーションを 1 つの DataPart として持つ。
    public static func envelopeArtifact(id: ArtifactID, presentation: Presentation) throws -> Artifact {
        try artifact(id: id, kind: .envelope, payload: presentation)
    }

    /// 追記イベント用の単一スライドアーティファクト。
    public static func slideArtifact(id: ArtifactID, page: Page) throws -> Artifact {
        try artifact(id: id, kind: .slide, payload: page)
    }

    /// バッチ更新アーティファクト：現在のプレゼンテーションに適用する要素レベルの編集。
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

/// ストリームレベルのアセンブラ：A2A ストリームのすべての TaskArtifactUpdateEvent を受け取り、
/// 最初の gslides アーティファクトに固定してそれ以外を無視する。
public struct GSlidesArtifactAssembler: Sendable {
    public private(set) var artifactId: ArtifactID?
    public private(set) var assembler = GSlidesAssembler()

    public var presentation: Presentation? { assembler.presentation }
    public var isComplete: Bool { assembler.isComplete }

    public init() {}

    /// イベントが追跡中の gslides アーティファクトに属していた場合 true を返す。
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
