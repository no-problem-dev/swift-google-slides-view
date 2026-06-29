# ``GSlidesRenderer``

iOS および macOS で Google Slides プレゼンテーションをレンダリングする SwiftUI ビュー群。

## Overview

GSlidesRenderer は `Presentation`（GSlidesSchema 由来）をネイティブ SwiftUI ビューへ変換する。各スライドは EMU ページ座標系の固定アスペクト 16:9 キャンバスにレンダリングされる。明示的なジオメトリ（size + transform）を持つ要素は絶対配置し、ジオメトリを持たないセマンティック層要素はレイアウト名に応じたスタック配置にフォールバックする。

カラーはプレゼンテーションのテーマから取得する。master/layout/slide の `ColorScheme` を ``PresentationColorPalette`` 経由でデザインシステムの `ColorPalette` へ射影するため、スライドコンテンツと DS クロームの両方が同じ `@Environment(\.colorPalette)` を共有する。

画像読み込みは ``GSlidesImageProvider`` で差し替え可能。エクスポート時は `PresentationImagePreloader`（GSlidesExport）が構築したプロバイダーを渡して同期描画を保証し、省略時はライブレンダリング用として `AsyncImage` にフォールバックする。

## Topics

### スライドビュー

- ``GSlidesSlideView``
- ``GSlidesPresentationView``

### ナビゲーションビュー

- ``GSlidesCarouselView``
- ``GSlidesStackView``
- ``GSlidesFullScreenView``

### テーマ

- ``PresentationTheme``
- ``PresentationColorPalette``

### 画像読み込み

- ``GSlidesImageProvider``
