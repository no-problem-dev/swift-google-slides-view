# ``GSlidesExport``

Google Slides プレゼンテーションを PDF および画像ファイルとして出力する。

## Overview

GSlidesExport は `Presentation`（`GSlidesSchema` 由来）をファイル出力用データへ変換する。レンダリングのプリミティブには `GSlidesRenderer` の `GSlidesSlideView` を使用する。両レンダラーは `@MainActor` で SwiftUI の `ImageRenderer` を使って各スライドを `CGContext` に描画するため、SwiftUI をサポートするプラットフォーム（iOS 16+・macOS 13+）であればどこでも動作する。

### 画像エクスポート

``PresentationImageRenderer`` はスライドごとに `CGImage` を生成する。デフォルトのピクセルサイズは 1920×1080。`pngData(_:)` は PNG `Data` としてエンコードした画像を返す。`stackedPNG(_:spacing:)` は全スライドを縦長の単一 PNG に合成する（SNS カルーセル用途に便利）。

### PDF エクスポート

``PresentationPDFRenderer`` はスライド 1 枚 1 ページのマルチページ PDF を書き出す。デフォルトのポイントサイズは 960×540 pt（= 10 in × 5.625 in）。`pdfData(_:)` は生バイトを返し、`pdfFile(_:filename:)` はデータを一時ファイルに書き込んで `URL` を返す。`ShareLink` や `fileExporter` にそのまま渡せる。

### 画像プリロード

両レンダラーはオプションで `GSlidesImageProvider` を受け取る。``PresentationImagePreloader/provider(for:)`` で構築したプロバイダーを渡すと、`image` 要素と `sheetsChart` 要素がすべて同期的に描画される。省略すると `AsyncImage` が使われ、エクスポートスナップショット時に空白フレームになる可能性がある。`PresentationImagePreloader` はレンダリングパスが始まる前に参照されているすべての URL を並行してフェッチする。

```swift
import GSlidesExport

// 画像をプリロードしてから PDF にエクスポートする
let provider = await PresentationImagePreloader.provider(for: presentation)
let pdfURL = try await MainActor.run {
    try PresentationPDFRenderer.pdfFile(
        presentation,
        filename: "Q3 Deck",
        imageProvider: provider
    )
}

// またはスライドごとに PNG としてエクスポートする
let pngFiles = await MainActor.run {
    PresentationImageRenderer.pngData(presentation, imageProvider: provider)
}
```

## Topics

### プリロード

- ``PresentationImagePreloader``

### PDF

- ``PresentationPDFRenderer``

### 画像

- ``PresentationImageRenderer``
