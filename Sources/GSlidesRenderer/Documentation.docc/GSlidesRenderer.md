# ``GSlidesRenderer``

SwiftUI views that render Google Slides presentations on iOS and macOS.

## Overview

GSlidesRenderer turns a `Presentation` (from GSlidesSchema) into native SwiftUI views. Each slide is
rendered on a fixed-aspect 16:9 canvas in EMU page coordinates; elements with explicit geometry
are placed absolutely, while semantic-tier elements without geometry fall back to a
layout-name-aware stack.

Colors come from the presentation's theme: the master/layout/slide `ColorScheme` is projected
onto the design system's `ColorPalette` via ``PresentationColorPalette``, so both slide content
and any DS chrome share the same `@Environment(\.colorPalette)`.

Image loading is pluggable via ``GSlidesImageProvider``: supply one built by
`PresentationImagePreloader` (from GSlidesExport) for synchronous export, or omit it to fall back to
`AsyncImage` for live rendering.

## Topics

### Slide views

- ``GSlidesSlideView``
- ``GSlidesPresentationView``

### Navigation views

- ``GSlidesCarouselView``
- ``GSlidesStackView``
- ``GSlidesFullScreenView``

### Theming

- ``PresentationTheme``
- ``PresentationColorPalette``

### Image loading

- ``GSlidesImageProvider``
