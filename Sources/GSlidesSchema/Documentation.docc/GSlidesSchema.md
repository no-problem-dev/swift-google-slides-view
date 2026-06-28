# ``GSlidesSchema``

The authoritative Swift mirror of the Google Slides API presentation model.

## Overview

GSlidesSchema provides the foundational types that every other library in this package builds on.
All field names and enum values mirror the [Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1)
exactly — `EnumParityTests` and `SpecProvenanceTests` enforce this parity automatically so the
mirror never drifts from the live spec.

Types are modeled as open-ended `SpecEnum` structs (not Swift enums) so future API values decode
losslessly. `knownValues` is tested against the pinned discovery document revision.

This library has **no UI or platform dependencies** and can be used from CLI, server, or test
targets without importing SwiftUI or UIKit.

### Package-wide module map

The full `swift-google-slides-view` package is organized into nine libraries, each with a
focused responsibility. GSlidesSchema is the shared data layer that all of them depend on.

**GSlidesLayout** translates the schema's EMU dimensions and predefined-layout vocabulary
into renderable geometry. It resolves the Master → Layout → Slide placeholder inheritance
chain (`PlaceholderResolver`), matches semantic slide content to the best-fit layout
(`LayoutMatcher`), and encodes the entire deck design — placeholder rectangles, typography
roles, color-theme tokens, and spacing scales — as data (`PresentationTemplate`,
`SlideDesignSystem`, `ThemeSpec`).

**GSlidesPrompt** is the LLM boundary. `GSlidesGenerationContract` injects a JSON Schema
for the compact `SemanticPresentation` type into a system prompt and validates the model's
output on the way back in. `GSlidesThemeContract` does the same for color-scheme generation.
`PresentationExpander` converts a validated `SemanticPresentation` into a fully-assembled
`Presentation` ready for rendering or export.

**GSlidesRequests** contains the generated `Codable` request types that mirror the Slides
API's `batchUpdate` vocabulary — `Request`, `CreateSlideRequest`, `InsertTextRequest`, and
60-plus sibling types. These are the values `GSlidesEdit` executes locally and `GSlidesA2A`
streams over the wire.

**GSlidesEdit** implements a pure in-memory `batchUpdate` executor with atomic, preflight-
validated semantics — the same atomicity guarantee as the real API, without any network
calls.

**GSlidesAssembly** is a protocol-agnostic chunk reducer. It assembles a `Presentation`
from a sequence of `GSlidesChunk` values (envelope / slide / batchUpdate), making streaming
construction first-class.

**GSlidesA2A** bridges the A2A agent protocol to `GSlidesAssembly`. It encodes and decodes
`TaskArtifactUpdateEvent` values so an A2A server can stream a presentation slide-by-slide
to a client without inventing a custom wire format.

**GSlidesRenderer** turns a `Presentation` into native SwiftUI views. `GSlidesSlideView`
renders a single slide on a fixed-aspect 16:9 canvas; navigation views (`GSlidesCarouselView`,
`GSlidesStackView`, `GSlidesFullScreenView`) compose multiple slides into interactive
browsing UIs.

**GSlidesExport** converts a `Presentation` to files. `PresentationPDFRenderer` produces a
multi-page PDF; `PresentationImageRenderer` produces per-slide PNG images or a single
stacked PNG. `PresentationImagePreloader` preloads every image URL referenced in the
presentation so the export renderers draw them synchronously.

## Topics

### Presentation structure

- ``Presentation``
- ``Page``
- ``PageElement``

### Colors and theme

- ``RgbColor``
- ``ThemeColorType``
- ``OpaqueColor``
- ``OptionalColor``
- ``SolidFill``
- ``ColorScheme``
- ``ThemeColorPair``

### Layout and geometry

- ``PredefinedLayout``
- ``LayoutReference``
- ``Size``
- ``Dimension``
- ``AffineTransform``

### Text

- ``TextContent``
- ``TextElement``
- ``TextRun``
- ``TextStyle``
- ``ParagraphMarker``

### API spec pinning

- ``GSlidesSpec``
- ``SpecEnum``
