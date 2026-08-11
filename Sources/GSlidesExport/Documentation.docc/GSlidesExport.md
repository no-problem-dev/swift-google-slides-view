# ``GSlidesExport``

Writes a Google Slides presentation out as a PDF or as PNG images.

## Overview

GSlidesExport turns a `Presentation` into file data, using `GSlidesSlideView` from `GSlidesRenderer`
as the drawing primitive. Both renderers are `@MainActor` and draw each slide into a `CGContext`
through SwiftUI's `ImageRenderer`, so they work anywhere SwiftUI does — iOS 17+ and macOS 14+ — with
no UIKit dependency, including from a command-line test.

### Preload images first

Rendering is synchronous, but `AsyncImage` is not. Any image the renderer has to fetch during an
export snapshots blank. Build a provider with ``PresentationImagePreloader/provider(for:)`` and pass
it to whichever renderer you use.

The preloader fetches image and Sheets-chart URLs concurrently before any drawing starts. Two limits
are worth knowing: a URL that fails to load is dropped silently and its element renders as a
placeholder, and there is no timeout or concurrency cap, so a deck referencing many slow URLs waits
for all of them.

### Image export

``PresentationImageRenderer`` produces one `CGImage` per slide at 1920×1080 by default; the point
size is always half the pixel size because the renderer is fixed at scale 2. `pngData(_:)` encodes
them as PNG `Data`. `stackedPNG(_:spacing:)` composites every slide into one tall PNG on a white
background, which suits a social carousel — at the cost of holding the whole stack in memory,
roughly 8 MB per slide at the default size.

A slide that fails to render is dropped rather than substituted, so the returned array can be shorter
than the slide count. Do not assume index *i* is slide *i*.

### PDF export

``PresentationPDFRenderer`` writes a multi-page PDF, one page per slide, at 960×540 points by default
(10 in × 5.625 in). `pdfData(_:)` returns the bytes; `pdfFile(_:filename:)` writes them to a
temporary file and returns a `URL` for `ShareLink` or `fileExporter`. Neither throws on an empty
deck — you get a zero-page PDF — and the temporary file is not cleaned up for you.

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

// Or export one PNG per slide
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
