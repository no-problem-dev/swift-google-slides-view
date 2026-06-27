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
