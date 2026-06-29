# ``GSlidesPrompt``

LLM 向けコントラクトと、構造化スライド生成・テーマ設計用のセマンティック型。

## Overview

GSlidesPrompt は「モデル ↔ パッケージ」の境界を定義する。LLM が出力すべき内容を定め、
その出力が完全な `Presentation` へ安全に展開できることを検証する。2 つの独立した
コントラクトが、2 つの構造化出力インターフェースをそれぞれ担う。

### 生成コントラクト

``GSlidesGenerationContract`` はスライドコンテンツを管理する。``SemanticPresentation`` 型の
JSON Schema を公開し — コンパクトでモデルが扱いやすいデッキ表現 —
その正確なスキーマをシステムプロンプトに注入できる。`validate(_:)` はサンドイッチの受信側を担い、
厳格なデコードとセマンティックチェック（デッキが空でない・レイアウト名が既知）を実行する。
`presentation(from:themeSpec:)` は生のモデルバイトから完全に展開した `Presentation` への
エンドツーエンドパス。

``SemanticPresentation`` はスライドごとに ``SemanticSlide`` を持つ。各スライドは
``SemanticBody``（テキスト、バレット、画像 URL、``SemanticMetric`` カード、
``SemanticChart``、``SemanticStep`` フロー、``SemanticQuote``、``SemanticTable``）を
任意に組み合わせて持つことができ、``PresentationExpander`` が Slides API ネイティブの
ページ要素にマッピングする。

### テーマコントラクト

``GSlidesThemeContract`` はカラースキーム生成を管理する。12 個の編集可能な
`ThemeColorType` スロットに制限した `ColorScheme` の JSON Schema と、`promptBlock()` —
プロンプトにそのまま貼り付けられるシステム指示ブロック（ルール + スキーマ + ワーク済み例）— を公開する。
`themeSpec(from:)` はモデルの出力を検証し、マスターページへの焼き込みに準備が整った
``ThemeSpec`` を返す。

```swift
import GSlidesPrompt

// --- スライド生成 ---
let schemaData = try GSlidesGenerationContract.jsonSchemaData()
let systemPrompt = """
以下のスキーマに合う JSON プレゼンテーションを生成してください:
\(String(decoding: schemaData, as: UTF8.self))
"""

// モデル出力を検証して完全な Presentation に展開する
let presentation = try GSlidesGenerationContract.presentation(from: modelOutputData)

// --- テーマ生成 ---
let themeInstructions = GSlidesThemeContract.promptBlock()
let themeSpec = try GSlidesThemeContract.themeSpec(from: modelThemeData)
```

## Topics

### 生成コントラクト

- ``GSlidesGenerationContract``
- ``GenerationContractError``

### テーマコントラクト

- ``GSlidesThemeContract``
- ``GSlidesThemeContractError``

### セマンティックスライドモデル

- ``SemanticPresentation``
- ``SemanticSlide``
- ``SemanticBody``
- ``SemanticBullet``
- ``SemanticMetric``
- ``SemanticChart``
- ``SemanticChartBar``
- ``SemanticStep``
- ``SemanticQuote``
- ``SemanticTable``

### 展開とフォーマット

- ``PresentationExpander``
- ``GSlidesExampleFormatter``
