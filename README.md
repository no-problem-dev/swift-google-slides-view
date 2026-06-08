# swift-google-slides-view

Render Google Slides API presentation JSON in SwiftUI.

Google Slides API の presentation スキーマ（のセマンティック・サブセット = プロファイル）に準拠した JSON を、SwiftUI で 16:9 スライドとしてレンダリングする Swift Package。LLM エージェントにスキーマ準拠 JSON を生成させ、A2A Artifact ストリーミングで 1 枚ずつ配信する用途を主眼に設計しているが、スキーマとレンダラ自体は LLM にも A2A にも依存しない。

> This project is not affiliated with, endorsed by, or sponsored by Google. "Google Slides" is a trademark of Google LLC. The schema vocabulary follows the publicly documented [Google Slides API](https://developers.google.com/slides/api) discovery document.

## 設計原則

1. **語彙を発明しない** — フィールド名・enum は本家 discovery document と同名。Swift の enum が本家の部分集合であることをテストで強制（enum parity）。North-star: 実際の `presentations.get` レスポンス（サブセット）がそのまま decode → レンダリングできること
2. **依存の向きは内→外** — スキーマは何も知らない。プロトコル依存はアダプタへ、UI 依存は葉へ
3. **CLI で TDD** — レンダラ以外の全ターゲットは UI 非依存で、`swift test` が CLI で完結する

## ターゲット構成

| ターゲット | 責務 | 依存 |
|---|---|---|
| `GSlidesSchema` | プロファイルの Codable モデル + vendored discovery doc（SSOT） | swift-structured-data |
| `GSlidesLayout` | コンテンツ → predefinedLayout マッチング、placeholder 解決、EMU 計算 | GSlidesSchema |
| `GSlidesAssembly` | チャンク列 `(payload, append, lastChunk)` → presentation 状態の純関数 reducer | GSlidesSchema |
| `GSlidesPrompt` | LLM 構造化出力スキーマ + few-shot 例（契約の提供のみ） | GSlidesSchema |
| `GSlidesA2A` | A2A Artifact/DataPart ⇄ schema coding、ストリームイベント写像 | + A2ACore |
| `GSlidesRequests` | batchUpdate write モデル（44 Request + Response の型安全ミラー） | GSlidesSchema |
| `GSlidesRenderer` | SwiftUI レンダラ（16:9 キャンバス、EMU→pt、デッキテーマ → DS ColorPalette） | + DesignSystem |

## テーマ

デッキの `ColorScheme`（master/layout/slide 継承）を DesignSystem の `ColorPalette` に射影する（`DeckColorPalette`）。
`ACCENT1→primary`、`TEXT1/DARK1→onSurface`、`BACKGROUND1/LIGHT1→background` のように DS のセマンティックスロットを埋め、
スライドの中身とクロームを同じ `@Environment(\.colorPalette)` で描く — 「Google Slides のテーマ忠実再現」と「デザインシステム統一」を両立する。
`basePalette` でデッキが定義しないスロットのフォールバックを差し替え可能。

## 使い方

```swift
// 受信側（A2A ストリーム → 表示）
var assembler = GSlidesArtifactAssembler()
for try await event in artifactEvents {           // TaskArtifactUpdateEvent
    try assembler.apply(event)                    // gslides 以外の artifact は自動スキップ
}
GSlidesDeckView(presentation: assembler.presentation!)

// 生成側（LLM 構造化出力 → 配信）
let schema = try GSlidesGenerationContract.jsonSchemaData()  // モデルに渡す JSON Schema
let presentation = try GSlidesGenerationContract.presentation(from: llmOutput)  // validate + expand
let event = try GSlidesArtifactCoding.envelopeEvent(
    taskId: taskId, contextId: contextId, artifactId: "deck", presentation: presentation
)
```

スナップショット確認: `GSLIDES_SNAPSHOT_DIR=/tmp/snap swift test --filter SnapshotDumpTests`

## ロードマップ

- [x] M0 scaffold + vendored spec
- [x] M1 GSlidesSchema: fixtures round-trip + enum parity
- [x] M2 GSlidesLayout: md2googleslides ルール移植 parity
- [x] M3 GSlidesAssembly: reducer（append / 全置換 / lastChunk / unknown layout first-class）
- [x] M4 GSlidesA2A: イベント写像 + ワイヤ round-trip
- [x] M5 GSlidesPrompt: validation sandwich
- [x] M6 GSlidesRenderer: CLI ImageRenderer スモーク + スナップショットダンプ
- [ ] M7 デモ統合（A2AResearchDemo content 層）

## License

MIT. Vendored assets and ported test rules from [md2googleslides](https://github.com/googleworkspace/md2googleslides) (Apache-2.0) — see [NOTICE](NOTICE).
