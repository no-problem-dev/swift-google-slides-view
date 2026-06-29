# ``GSlidesAssembly``

型付きチャンク列からストリーミング `Presentation` を組み立てる純粋リデューサー。

## Overview

GSlidesAssembly は Swift Google Slides ストリーミングパイプラインのプロトコル非依存な受信側。中心的な抽象は ``GSlidesChunk`` — 3 種類のプレゼンテーションストリームペイロードのいずれかを運ぶ型付きエンベロープ。

- **envelope** — 完全な `Presentation`。既存の状態をすべて置き換える。
- **slide** — 単一の `Page`。`slides` に追加される。envelope より先にスライドチャンクが届いた場合は暗黙の空プレゼンテーションを生成するため、スライド先行ストリームもきれいに組み立てられる。
- **batchUpdate** — `BatchUpdatePresentationRequest`（`GSlidesRequests` 由来）。ローカル `batchUpdate` エグゼキューター経由で現在の状態にアトミックに適用される。

``GSlidesAssembler`` はリデューサー本体。純粋な `mutating` 値型で、`apply(_:)` を呼ぶたびに 1 チャンク分だけ状態が進む。`lastChunk == true` でストリームが封印され、以降に envelope や slide チャンクが届くと ``GSlidesAssemblyError/chunkAfterCompletion`` で拒否される。完了後の `batchUpdate` チャンクは受理される（完成したプレゼンテーションを調整するエージェントを黙って無視するべきではないため）。

便利なスタティックメソッド `assemble(_:)` はチャンク列全体を 1 呼び出しで畳み込み、完成した `Presentation` を返す。テストやワンショットのパイプラインコンシューマーに便利。

```swift
import GSlidesAssembly

var assembler = GSlidesAssembler()

// ストリームからチャンクが届くたびに投入する
for event in stream {
    try assembler.apply(event)
}

if let presentation = assembler.presentation, assembler.isComplete {
    // レンダリング可能
}

// または列全体を一度に畳み込む
let presentation = try GSlidesAssembler.assemble(chunks)
```

## Topics

### チャンク基本型

- ``GSlidesChunk``

### リデューサー

- ``GSlidesAssembler``

### エラー

- ``GSlidesAssemblyError``
