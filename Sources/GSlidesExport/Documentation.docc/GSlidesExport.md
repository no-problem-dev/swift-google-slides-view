# ``GSlidesExport``

PDF and raster-image export for Google Slides presentations.

## Overview

GSlidesExport converts a `Presentation` (from `GSlidesSchema`) into file-ready output
using `GSlidesRenderer`'s `GSlidesSlideView` as the render primitive. Both renderers are
`@MainActor` and use SwiftUI's `ImageRenderer` to draw each slide into a `CGContext`,
so they run on any platform that supports SwiftUI (iOS 16+, macOS 13+).

### Image export

``PresentationImageRenderer`` produces `CGImage` values — one per slide — at a configurable
pixel size (default 1920×1080). `pngData(_:)` returns the images encoded as PNG `Data`
values. `stackedPNG(_:spacing:)` composites all slides into a single tall PNG, which is
convenient for social-media carousels.

### PDF export

``PresentationPDFRenderer`` writes a multi-page PDF with one slide per page, at a
configurable point size (default 960×540 pt, i.e. 10 in × 5.625 in). `pdfData(_:)`
returns the raw bytes; `pdfFile(_:filename:)` writes them to a temporary file and
returns the `URL`, ready for `ShareLink` or `fileExporter`.

### Image preloading

Both renderers accept an optional `GSlidesImageProvider`. Pass one built by
``PresentationImagePreloader/provider(for:)`` to ensure every `image` and `sheetsChart`
element renders synchronously — without it, `AsyncImage` snapshots at blank frames.
`PresentationImagePreloader` fetches all referenced URLs concurrently before the render
pass begins.

```swift
import GSlidesExport

// Preload images, then export to PDF
let provider = await PresentationImagePreloader.provider(for: presentation)
let pdfURL = try await MainActor.run {
    try PresentationPDFRenderer.pdfFile(
        presentation,
        filename: "Q3 Deck",
        imageProvider: provider
    )
}

// Or export each slide as PNG
let pngFiles = await MainActor.run {
    PresentationImageRenderer.pngData(presentation, imageProvider: provider)
}
```

## Topics

### Preloading

- ``PresentationImagePreloader``

### PDF

- ``PresentationPDFRenderer``

### Images

- ``PresentationImageRenderer``
