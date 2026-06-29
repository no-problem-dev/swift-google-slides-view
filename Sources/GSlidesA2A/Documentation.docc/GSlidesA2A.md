# ``GSlidesA2A``

A2A プロトコルイベントを `GSlidesChunk` 値へ写像する Agent-to-Agent ストリーミングコーデック。

## Overview

GSlidesA2A は [A2A プロトコル](https://github.com/google/A2A) と `GSlidesAssembly` のチャンクベースアセンブリパイプラインをブリッジする。プレゼンテーションをクライアントにストリーミング配信したい A2A サーバーはカスタムワイヤーフォーマットを発明する必要はなく、標準の `TaskArtifactUpdateEvent` を `DataPart` ペイロード付きで emit するだけでよい。2 つのメタデータキーでアーティファクトが gslides ストリームであることとチャンクの種類を宣言する。

``GSlidesA2AVocabulary`` はそれらのキー（`gslides.schema` と `gslides.kind`）およびメディアタイプ（`application/json`）を文書化する。``GSlidesArtifactCoding`` はコーデック本体。送信側ヘルパー（`envelopeEvent`・`slideEvent`・`batchUpdateEvent`）は `Presentation`・`Page`・`[Request]` から正しく構造化されたイベントを構築し、受信側ヘルパー（`chunks(from:)`・`presentation(from:)`）はイベントを ``GSlidesAssembly/GSlidesChunk`` 値に展開して ``GSlidesAssembly/GSlidesAssembler`` に直接渡せる形にする。

``GSlidesArtifactAssembler`` は便利ラッパー。イベントフィルタリング（非 gslides アーティファクトを無視）・アーティファクト ID 追跡・チャンクアセンブリを 1 つの `mutating apply(_:)` 呼び出しにまとめる。ストリーミングされたプレゼンテーションを再構築するクライアントが必要とする最小サーフェス。

```swift
import GSlidesA2A

// 送信側 — スライドを 1 枚ずつ emit する
let event = try GSlidesArtifactCoding.slideEvent(
    taskId: taskId,
    contextId: contextId,
    artifactId: "deck",
    page: slide,
    lastChunk: isLast
)

// 受信側 — ストリームが完了するまでイベントを蓄積する
var receiver = GSlidesArtifactAssembler()
for event in a2aStream {
    try receiver.apply(event)
}
if let presentation = receiver.presentation, receiver.isComplete {
    // GSlidesRenderer へ渡す
}
```

## Topics

### ボキャブラリー

- ``GSlidesA2AVocabulary``

### コーデック

- ``GSlidesArtifactCoding``

### ストリームアセンブラー

- ``GSlidesArtifactAssembler``

### エラー

- ``GSlidesA2AError``
