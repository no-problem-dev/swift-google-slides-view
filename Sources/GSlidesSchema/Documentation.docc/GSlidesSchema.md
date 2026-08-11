# ``GSlidesSchema``

Google Slides API プレゼンテーションモデルのセマンティック・サブセットの Swift ミラー。

> **非公式。** Google と提携・推薦・後援のいずれの関係もない。「Google Slides」は Google LLC の商標である。ここにあるのは Google Slides API の presentation スキーマのセマンティック・サブセットであり、Google の製品でも API クライアントでもない。API に準拠することはこのプロジェクトの目標ではない。

## Overview

GSlidesSchema はこのパッケージ内の全ライブラリが依拠する基盤型を提供する。
モデル化している範囲のフィールド名と enum 値は [Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1) と同じ語彙を使う。
`EnumParityTests` と `SpecProvenanceTests` がこのパリティを自動検証し、ミラーがピン留めした discovery document とずれないよう見張っている。

型は Swift enum ではなくオープンエンドな `SpecEnum` 構造体として定義されているため、将来の API 値も損失なくデコードできる。`knownValues` はピン留めされた discovery document のリビジョンに対してテストされる。

このライブラリは **UI・プラットフォーム依存なし**。SwiftUI や UIKit をインポートせずに CLI・サーバー・テストターゲットから利用できる。

### パッケージ全体のモジュール構成

`swift-google-slides-view` パッケージは 9 つのライブラリで構成され、各ライブラリが明確な責務を持つ。GSlidesSchema は全ライブラリが依存する共有データ層。

**GSlidesLayout** は、スキーマの EMU 寸法と predefined-layout ボキャブラリーをレンダリング可能なジオメトリへ変換する。Master → Layout → Slide のプレースホルダー継承チェーンを解決し（`PlaceholderResolver`）、セマンティックなスライドコンテンツを最適レイアウトへマッチングする（`LayoutMatcher`）。デッキ設計全体（プレースホルダー矩形・タイポグラフィロール・カラーテーマトークン・スペーシングスケール）もデータとして表現する（`PresentationTemplate`・`SlideDesignSystem`・`ThemeSpec`）。

**GSlidesPrompt** は LLM バウンダリー。`GSlidesGenerationContract` はコンパクトな `SemanticPresentation` 型の JSON Schema をシステムプロンプトに注入し、モデル出力を受け取る際にバリデーションを行う。`GSlidesThemeContract` もカラースキーム生成に同様の仕組みを提供する。`PresentationExpander` はバリデーション済みの `SemanticPresentation` を、レンダリングまたはエクスポートが可能な完全な `Presentation` へ展開する。

**GSlidesRequests** は、Slides API の `batchUpdate` ボキャブラリーをミラーした Codable リクエスト型（`Request`・`CreateSlideRequest`・`InsertTextRequest` ほか 60 種以上）を含む。これらは `GSlidesEdit` がローカル実行し、`GSlidesA2A` がワイヤーでストリーミングする値。

**GSlidesEdit** は、純粋なインメモリ `batchUpdate` エグゼキューターをアトミック・preflight バリデーション付きで実装する。本家 API と同じアトミシティ保証をネットワーク呼び出しなしで提供する。

**GSlidesAssembly** はプロトコル非依存のチャンクリデューサー。`GSlidesChunk` 値の列（envelope / slide / batchUpdate）から `Presentation` を組み立て、ストリーミング構築をファーストクラスにする。

**GSlidesA2A** は A2A エージェントプロトコルを `GSlidesAssembly` へブリッジする。`TaskArtifactUpdateEvent` 値をエンコード・デコードすることで、A2A サーバーがカスタムワイヤーフォーマットを発明せずにスライドを 1 枚ずつストリーミング配信できる。

**GSlidesRenderer** は `Presentation` をネイティブ SwiftUI ビューへ変換する。`GSlidesSlideView` は 1 枚のスライドを固定アスペクト 16:9 キャンバスにレンダリングし、ナビゲーションビュー（`GSlidesCarouselView`・`GSlidesStackView`・`GSlidesFullScreenView`）で複数スライドをインタラクティブに閲覧できる。

**GSlidesExport** は `Presentation` をファイルに変換する。`PresentationPDFRenderer` はマルチページ PDF を生成し、`PresentationImageRenderer` はスライドごとの PNG または縦長の結合 PNG を生成する。`PresentationImagePreloader` はエクスポート前にすべての画像 URL を並行してプリロードする。

## Topics

### プレゼンテーション構造

- ``Presentation``
- ``Page``
- ``PageElement``

### カラーとテーマ

- ``RgbColor``
- ``ThemeColorType``
- ``OpaqueColor``
- ``OptionalColor``
- ``SolidFill``
- ``ColorScheme``
- ``ThemeColorPair``

### レイアウトと座標系

- ``PredefinedLayout``
- ``LayoutReference``
- ``Size``
- ``Dimension``
- ``AffineTransform``

### テキスト

- ``TextContent``
- ``TextElement``
- ``TextRun``
- ``TextStyle``
- ``ParagraphMarker``

### API 仕様の固定

- ``GSlidesSpec``
- ``SpecEnum``
