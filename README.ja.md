[English](./README.md) | 日本語

# swift-google-slides-view

スライドデッキを SwiftUI アプリの中でそのまま表示する — エージェントがまだ書いている途中のデッキも、1 枚ずつ。

> **非公式。** Google とは無関係であり、承認も後援も受けていない。"Google Slides" は Google LLC の商標。本パッケージは [Google Slides API](https://developers.google.com/slides/api) の presentation スキーマのセマンティック・サブセットを描画するものであり、Google の製品でも API クライアントでもない。API への準拠はこのプロジェクトの目標ではない。

## 概要

プレゼンテーションは Slides API が返すのと同じ JSON で表す。だからデッキの出どころはファイルでも
サーバーでも、「作って」と頼んだ言語モデルでもよい。描画は 16:9 キャンバス上の素の SwiftUI —
WebView もヘッドレスブラウザも Google の SDK もアプリに入らない。

- **届いた端から描ける** — ストリームのチャンクを流し込むたびに presentation 状態が組み上がるので、
  残りが書かれている間にスライドが出てくる
- **編集は全部通るか、何も起きないか** — 変更のバッチは丸ごと適用されるかデッキが無傷のままか
  どちらかで、本家 API と同じ挙動。中途半端に適用された絵が出ることはない
- **問題は 1 回で全部返る** — 検証は最初の 1 件で止めず全違反を集めてから適用に進む。
  モデルが自分の出力を直すのにミス 1 個あたり 1 往復かける必要がない
- **拒否はどのフィールドがなぜ駄目かを言う** — リクエストへの dotted path と安定した理由コードを持ち、
  そのままプロンプトに整形して戻せる
- **デッキ自身の色が UI を駆動する** — プレゼンテーションのカラースキームがデザインシステムの
  セマンティックスロットを埋めるので、スライドの中身と周囲のクロームが同じテーマで揃う
- **画面がなくても書き出せる** — PDF / PNG へ出力できる
- **CLI でテストできる** — UI に依存するのは描画と書き出しのターゲットだけ。スキーマ・レイアウト・
  組み立て・編集の各層はシミュレータなしで `swift test` に載る

## クイックスタート

artifact イベントのストリームからデッキを組み立てて表示する:

```swift
var assembler = GSlidesArtifactAssembler()
for try await event in artifactEvents {           // TaskArtifactUpdateEvent
    try assembler.apply(event)                    // gslides 以外の artifact は読み飛ばす
}
GSlidesPresentationView(presentation: assembler.presentation!)
```

モデルにデッキを作らせて配信する:

```swift
let schema = try GSlidesGenerationContract.jsonSchemaData()                    // モデルに渡す JSON Schema
let presentation = try GSlidesGenerationContract.presentation(from: llmOutput) // 検証 + 展開
let event = try GSlidesArtifactCoding.envelopeEvent(
    taskId: taskId, contextId: contextId, artifactId: "deck", presentation: presentation
)
```

描画結果を目で確かめる: `GSLIDES_SNAPSHOT_DIR=/tmp/snap swift test --filter SnapshotDumpTests`

## ドキュメント

[**GSlidesSchema**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesschema/) — presentation モデルと、API のどこまでを覆うか ·
[**GSlidesRenderer**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesrenderer/) — SwiftUI ビューとテーマ ·
[**GSlidesEdit**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesedit/) — バッチ更新の適用と検証 ·
[**GSlidesA2A**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesa2a/) — デッキを artifact として流す ·
[**GSlidesExport**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesexport/) — PDF / PNG 出力

他: [GSlidesLayout](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslideslayout/)、
[GSlidesAssembly](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesassembly/)、
[GSlidesPrompt](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesprompt/)、
[GSlidesRequests](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesrequests/)。

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-google-slides-view", .upToNextMinor(from: "0.14.0")),
],
```

必要なプロダクトを追加する — 描くなら `GSlidesRenderer`、モデルだけ扱うなら `GSlidesSchema` 単体、
変更を適用するなら `GSlidesEdit`:

```swift
.product(name: "GSlidesRenderer", package: "swift-google-slides-view"),
.product(name: "GSlidesSchema",   package: "swift-google-slides-view"),
.product(name: "GSlidesEdit",     package: "swift-google-slides-view"),
```

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+

## ライセンス

MIT。同梱アセットと移植したテスト規則は [md2googleslides](https://github.com/googleworkspace/md2googleslides)（Apache-2.0）由来 — [NOTICE](NOTICE) を参照。
