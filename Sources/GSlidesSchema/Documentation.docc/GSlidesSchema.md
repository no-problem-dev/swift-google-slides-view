# ``GSlidesSchema``

A Swift mirror of a semantic subset of the Google Slides API presentation model.

> **Unofficial.** Not affiliated with, endorsed by, or sponsored by Google; "Google Slides" is a trademark of Google LLC. This renders a semantic subset of the [Google Slides API](https://developers.google.com/slides/api) presentation schema — it is not a Google product and not an API client. Conforming to the API is not a goal of this project.

## Overview

GSlidesSchema holds the value types every other library in this package is built on. Within the
subset it models, field names and enum values use the same vocabulary as the
[Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1), so a
payload decoded here can be handed back to the API unchanged. `EnumParityTests` and
`SpecProvenanceTests` fail if the mirror drifts from the pinned revision.

Enums are open-ended ``SpecEnum`` structs rather than Swift enums, so a value added to the API after
this mirror was generated decodes instead of throwing, and re-encodes with its original spelling.
Ask ``SpecEnum/isKnown`` when you need to tell a modeled value from a passed-through one.

Two things about this model differ from the API and will bite you if you assume otherwise:

- **Nearly every field is optional**, including ones the real `presentations.get` always returns.
  That is deliberate — an assembler holds partially received presentations — so a nil often means
  "not received yet" rather than "absent".
- **Lengths carry their unit.** ``Dimension`` pairs a bare `Double` with EMU or points, and the API
  mixes both: EMU for geometry, points for font sizes. 1 point = 12,700 EMU, 1 inch = 914,400 EMU.
  `GSlidesLayout` provides the conversions.

The library has **no UI or platform dependency**. It imports neither SwiftUI nor UIKit and is usable
from CLI, server and test targets.

### Where this sits in the package

`swift-google-slides-view` is nine libraries; GSlidesSchema is the data layer all of them share.
`GSlidesLayout` turns its EMU geometry into drawable rectangles, `GSlidesRequests` mirrors the
`batchUpdate` write model over the same types, `GSlidesEdit` applies those requests in memory,
`GSlidesPrompt` generates and expands presentations from LLM output, `GSlidesAssembly` and
`GSlidesA2A` build presentations from streamed chunks, and `GSlidesRenderer` and `GSlidesExport`
draw the result to SwiftUI, PDF and PNG.

## Topics

### Presentation structure

- ``Presentation``
- ``Page``
- ``PageElement``
- ``Indirect``

### Geometry and units

- ``Dimension``
- ``Size``
- ``AffineTransform``
- ``Unit``

### Layouts and placeholders

- ``PredefinedLayout``
- ``LayoutReference``
- ``Placeholder``
- ``PlaceholderType``

### Color and theme

- ``RgbColor``
- ``ThemeColorType``
- ``OpaqueColor``
- ``OptionalColor``
- ``SolidFill``
- ``ColorScheme``
- ``ThemeColorPair``

### Text

- ``TextContent``
- ``TextElement``
- ``TextRun``
- ``TextStyle``
- ``ParagraphMarker``
- ``ParagraphStyle``
- ``Bullet``
- ``List``
- ``AutoText``

### Pinning the API specification

- ``GSlidesSpec``
- ``SpecEnum``
