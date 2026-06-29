import Foundation
import GSlidesEdit
import GSlidesRequests
import GSlidesSchema

/// トランスポート非依存のチャンクプリミティブ。アダプタ（例: GSlidesA2A）が
/// プロトコルのストリームイベントをこれにマップし、リデューサーはプロトコル型を見ない。
public struct GSlidesChunk: Equatable, Sendable {
    /// ペイロードの内容 — プレゼンテーションストリームの 3 つの形状。
    public enum Kind: String, Equatable, Sendable {
        case envelope     // a full `Presentation` — replaces the state
        case slide        // a single `Page` — appended to `slides`
        case batchUpdate  // a `BatchUpdatePresentationRequest` — applied to the current state
    }

    public var payload: Data
    public var kind: Kind
    public var lastChunk: Bool

    /// ワイヤーの追記セマンティクス：完全なエンベロープでない限り、チャンクは先行状態の上に積み上がる。
    public var append: Bool { kind != .envelope }

    public init(payload: Data, kind: Kind = .envelope, lastChunk: Bool = false) {
        self.payload = payload
        self.kind = kind
        self.lastChunk = lastChunk
    }

    /// 後方互換: `append == false` → envelope、`append == true` → slide。
    public init(payload: Data, append: Bool, lastChunk: Bool = false) {
        self.init(payload: payload, kind: append ? .slide : .envelope, lastChunk: lastChunk)
    }
}

public enum GSlidesAssemblyError: Error, Hashable {
    case invalidPayload(String)
    case chunkAfterCompletion
}

/// チャンクシーケンスに対する純粋リデューサ：
/// - `.envelope`：ペイロードは完全な `Presentation` — 状態を置き換える。
/// - `.slide`：ペイロードは単一の `Page` — `slides` に追記する。エンベロープより前のスライドは
///   暗黙の空プレゼンテーションを作成するため、スライド先行ストリームでもアセンブル可能。
/// - `.batchUpdate`：ペイロードは `BatchUpdatePresentationRequest` — ローカルリデューサ経由で
///   現在の状態に適用する（プレゼンテーション再送なしの要素レベルライブ編集）。
/// - `lastChunk == true`：ストリームを完了する。以降のチャンクはエラー。
/// スローする apply は状態を変更しないまま返す。
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
