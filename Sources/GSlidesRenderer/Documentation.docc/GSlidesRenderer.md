# ``GSlidesRenderer``

SwiftUI views that draw Google Slides presentations on iOS and macOS.

## Overview

GSlidesRenderer turns a `Presentation` from `GSlidesSchema` into native SwiftUI views. Each slide is
drawn on a fixed-aspect canvas sized from the deck's own page size, in EMU page coordinates with the
origin at the top-left.

Elements that carry geometry — their own `size` and `transform`, or one inherited from the layout —
are positioned absolutely. Elements with no geometry fall back to a stacked layout driven by
placeholder type and the layout name, which is what a semantic deck that never went through the
layout template looks like.

### What happens to elements it does not model

Nothing is dropped silently. An element whose union member is newer than the schema mirror draws a
dashed placeholder box with a question-mark glyph; a speaker spotlight draws a person glyph; a video
draws its thumbnail with a play affordance rather than playing inline. A shape type with no path
geometry falls back to a plain rectangle. Shear is ignored throughout, so a rotated element renders
axis-aligned.

### Theming

Colors come from the deck itself. The master → layout → slide `ColorScheme` chain is projected onto a
design-system `ColorPalette` by ``PresentationColorPalette``, so slide content and surrounding chrome
both read the same `@Environment(\.colorPalette)`. Slots the presentation does not define fall
through to a base palette, which by default is the app's — set `basePalette` on a slide view to
control that.

### Images

Image loading is swappable through ``GSlidesImageProvider``. Leave it nil on screen and images load
progressively through `AsyncImage`. For export, pass a provider built by `PresentationImagePreloader`
in `GSlidesExport`: rendering is synchronous, so an unresolved `AsyncImage` snapshots blank.

### Text

Text is drawn from the flat `textElements` stream, regrouped into paragraphs. Bulleted paragraphs use
a hanging indent, so wrapped lines align under the text rather than under the glyph. The TEXT_AUTOFIT
shrink factor is reproduced from the value the API computed — it is not recalculated locally, so text
that overflows in these metrics still overflows. A font family that is not installed silently
resolves to the system font.

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
- ``GSlidesPalette``

### Image loading

- ``GSlidesImageProvider``
