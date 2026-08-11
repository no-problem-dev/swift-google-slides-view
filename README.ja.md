[English](./README.md) | 日本語

# swift-google-slides-view

Google Slides API の presentation JSON を SwiftUI でレンダリングする。

> **非公式。** Google と提携・推薦・後援のいずれの関係もない。「Google Slides」は Google LLC の商標である。ここでレンダリングするのは [Google Slides API](https://developers.google.com/slides/api) の presentation スキーマのセマンティック・サブセットであり、Google の製品でも API クライアントでもない。API に準拠することはこのプロジェクトの目標ではない。

Google Slides API の presentation スキーマのセマンティック・サブセット（プロファイル）に沿った JSON を、SwiftUI で 16:9 スライドとしてレンダリングする Swift Package。LLM エージェントにそのプロファイルの JSON を生成させ、A2A Artifact ストリーミングで 1 枚ずつ配信する用途を主眼に設計しているが、スキーマとレンダラ自体は LLM にも A2A にも依存しない。

## 設計原則

1. **語彙を発明しない** — フィールド名・enum は本家 discovery document と同名。Swift の enum が本家の部分集合であることをテストで強制（enum parity）。North-star: 実際の `presentations.get` レスポンス（サブセット）がそのまま decode → レンダリングできること
2. **依存の向きは内→外** — スキーマは何も知らない。プロトコル依存はアダプタへ、UI 依存は葉へ
3. **CLI で TDD** — レンダラ以外の全ターゲットは UI 非依存で、`swift test` が CLI で完結する

## ターゲット構成

| ターゲット | 責務 | 依存 |
|---|---|---|
| `GSlidesSchema` | プロファイルの Codable モデル + vendored discovery doc + 制約カタログ（SSOT） | swift-structured-data |
| `GSlidesLayout` | コンテンツ → predefinedLayout マッチング、placeholder 解決、EMU 計算 | GSlidesSchema |
| `GSlidesAssembly` | チャンク列 `(payload, append, lastChunk)` → presentation 状態の純関数 reducer | GSlidesSchema |
| `GSlidesPrompt` | LLM 構造化出力スキーマ + few-shot 例（契約の提供のみ） | GSlidesSchema |
| `GSlidesA2A` | A2A Artifact/DataPart ⇄ schema coding、ストリームイベント写像 | + A2ACore |
| `GSlidesRequests` | batchUpdate write モデル（44 Request + Response の型安全ミラー） | GSlidesSchema |
| `GSlidesEdit` | ローカル batchUpdate 実行 reducer + 2 層バリデーション（preflight + atomic apply） | GSlidesRequests |
| `GSlidesRenderer` | SwiftUI レンダラ（16:9 キャンバス、EMU→pt、デッキテーマ → DS ColorPalette） | + DesignSystem |
| `GSlidesExport` | Presentation → PDF / PNG（ImageRenderer + CGContext） | GSlidesRenderer |

## 編集とバリデーション（GSlidesEdit）

編集エージェントは独自語彙ではなく **Slides API の batchUpdate リクエスト**（`Request` 型のキュレートされた部分集合）を直接 emit する。適用は **decode → preflight → atomic apply** の 3 段：

- **2 層構造**: 下層（`Presentation.applying`）は本家同様 **all-or-nothing**（「1 件でも不正ならバッチ全体が失敗し、何も適用されない」）。上層（`PreflightValidator`）は送信前に **全違反を一括収集**し、エージェントが 1 パスで全部直せるようにする（サーバ往復を 1 回の判定に畳む）。
- **権威ある制約**: バリデーション規則は `Sources/GSlidesSchema/Resources/Spec/constraints-catalog.yaml`（一次仕様から逐語引用 + 出典 URL）が SSOT。objectId 正規表現/長さ/一意性、enum 網羅、oneof「ちょうど 1 つ」、field mask、テキスト範囲は **(A) API が弾く制約**として、ページ境界外への移動・退化変形（scale=0）は **(B) API が弾かないため呼び出し側が担保する制約**として検証する。
- **エラーモデル**: 拒否は `google.rpc.Status` + `BadRequest.FieldViolation` を再現した `BatchUpdateError` で返す。`field`（リクエストへの dotted path）・`reason`（`OBJECT_NOT_FOUND` 等の安定コード）・`description` を持ち、`promptFeedback(for:)` で LLM 自己修正用に整形できる。
- **仕様の凍結と drift 検出**: discovery doc は `scripts/fetch-discovery.sh` で取得し revision をピン。`SpecProvenanceTests` が revision と検証が依存する逐語プローズの不変を保証する。詳細は `Resources/Spec/PROVENANCE.md`。

## テーマ

デッキの `ColorScheme`（master/layout/slide 継承）を DesignSystem の `ColorPalette` に射影する（`DeckColorPalette`）。
`ACCENT1→primary`、`TEXT1/DARK1→onSurface`、`BACKGROUND1/LIGHT1→background` のように DS のセマンティックスロットを埋め、
スライドの中身とクロームを同じ `@Environment(\.colorPalette)` で描く — 「デッキ自身のテーマを反映すること」と「デザインシステム統一」を両立する。
`basePalette` でデッキが定義しないスロットのフォールバックを差し替え可能。

## 使い方

```swift
// 受信側（A2A ストリーム → 表示）
var assembler = GSlidesArtifactAssembler()
for try await event in artifactEvents {           // TaskArtifactUpdateEvent
    try assembler.apply(event)                    // gslides 以外の artifact は自動スキップ
}
GSlidesPresentationView(presentation: assembler.presentation!)

// 生成側（LLM 構造化出力 → 配信）
let schema = try GSlidesGenerationContract.jsonSchemaData()  // モデルに渡す JSON Schema
let presentation = try GSlidesGenerationContract.presentation(from: llmOutput)  // validate + expand
let event = try GSlidesArtifactCoding.envelopeEvent(
    taskId: taskId, contextId: contextId, artifactId: "deck", presentation: presentation
)
```

スナップショット確認: `GSLIDES_SNAPSHOT_DIR=/tmp/snap swift test --filter SnapshotDumpTests`

## Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-google-slides-view", from: "0.12.1"),
],
```

## ロードマップ

- [x] M0 scaffold + vendored spec
- [x] M1 GSlidesSchema: fixtures round-trip + enum parity
- [x] M2 GSlidesLayout: md2googleslides ルール移植 parity
- [x] M3 GSlidesAssembly: reducer（append / 全置換 / lastChunk / unknown layout first-class）
- [x] M4 GSlidesA2A: イベント写像 + ワイヤ round-trip
- [x] M5 GSlidesPrompt: validation sandwich
- [x] M6 GSlidesRenderer: CLI ImageRenderer スモーク + スナップショットダンプ
- [ ] M7 デモ統合（A2AResearchDemo content 層）

## ライセンス

MIT。[md2googleslides](https://github.com/googleworkspace/md2googleslides)（Apache-2.0）のテストルールを移植した vendored アセットを含む — [NOTICE](NOTICE) 参照。
