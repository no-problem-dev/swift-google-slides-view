English | [日本語](./README.ja.md)

# swift-google-slides-view

Show a slide deck natively in a SwiftUI app — including one an agent is still writing, a slide at a time.

> **Unofficial.** Not affiliated with, endorsed by, or sponsored by Google; "Google Slides" is a trademark of Google LLC. This renders a semantic subset of the [Google Slides API](https://developers.google.com/slides/api) presentation schema — it is not a Google product and not an API client. Conforming to the API is not a goal of this project.

## Overview

Presentations are described by the same JSON the Slides API returns, so a deck can come from a file,
from a server, or from a language model asked to produce one. Rendering is plain SwiftUI on a 16:9
canvas — no web view, no headless browser, and no Google SDK in your app.

- **Draw a deck as it arrives** — feed streamed chunks in and the presentation state rebuilds after
  each one, so slides appear while the rest is still being written
- **Edits are all-or-nothing** — a batch of changes either applies completely or leaves the deck
  untouched, matching the API's own behaviour, so a partial edit can never be shown
- **Every problem in one pass** — validation collects all violations before applying instead of
  stopping at the first, so a model fixing its own output does not need one round trip per mistake
- **Rejections say which field and why** — a dotted path into the offending request and a stable
  reason code, formattable straight back into a prompt
- **The deck's own colours drive the UI** — a presentation's colour scheme fills the design system's
  semantic slots, so slide content and surrounding chrome are themed together
- **Export without a screen** — render to PDF or PNG
- **Testable from the command line** — UI is confined to the rendering and export targets, so the
  schema, layout, assembly and edit layers run under `swift test` with no simulator

## Quick Start

Assemble a deck from a stream of artifact events and show it:

```swift
var assembler = GSlidesArtifactAssembler()
for try await event in artifactEvents {           // TaskArtifactUpdateEvent
    try assembler.apply(event)                    // non-gslides artifacts are skipped
}
GSlidesPresentationView(presentation: assembler.presentation!)
```

Ask a model for a deck, then publish it:

```swift
let schema = try GSlidesGenerationContract.jsonSchemaData()                    // give this to the model
let presentation = try GSlidesGenerationContract.presentation(from: llmOutput) // validate + expand
let event = try GSlidesArtifactCoding.envelopeEvent(
    taskId: taskId, contextId: contextId, artifactId: "deck", presentation: presentation
)
```

To eyeball rendered output: `GSLIDES_SNAPSHOT_DIR=/tmp/snap swift test --filter SnapshotDumpTests`

## Documentation

[**GSlidesSchema**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesschema/) — the presentation model and which parts of the API it covers ·
[**GSlidesRenderer**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesrenderer/) — the SwiftUI views and theming ·
[**GSlidesEdit**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesedit/) — applying and validating batch updates ·
[**GSlidesA2A**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesa2a/) — streaming a deck as artifacts ·
[**GSlidesExport**](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesexport/) — PDF and PNG output

Also: [GSlidesLayout](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslideslayout/),
[GSlidesAssembly](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesassembly/),
[GSlidesPrompt](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesprompt/),
[GSlidesRequests](https://no-problem-dev.github.io/swift-google-slides-view/documentation/gslidesrequests/).

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-google-slides-view", .upToNextMinor(from: "0.15.0")),
],
```

Add the products you need — `GSlidesRenderer` to draw, `GSlidesSchema` alone if you only handle the
model, `GSlidesEdit` to apply changes:

```swift
.product(name: "GSlidesRenderer", package: "swift-google-slides-view"),
.product(name: "GSlidesSchema",   package: "swift-google-slides-view"),
.product(name: "GSlidesEdit",     package: "swift-google-slides-view"),
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+

## License

MIT. Vendored assets and ported test rules from [md2googleslides](https://github.com/googleworkspace/md2googleslides) (Apache-2.0) — see [NOTICE](NOTICE).
