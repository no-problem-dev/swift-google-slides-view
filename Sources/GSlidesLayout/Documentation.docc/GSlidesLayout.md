# ``GSlidesLayout``

Geometry, coordinate conversion, layout matching, and slide design system for Google Slides presentations.

## Overview

GSlidesLayout is the design-data layer that sits between `GSlidesSchema` (wire types) and
`GSlidesRenderer` / `GSlidesAssembly` (consumers). Every measurement this library deals with uses
the Slides API's native unit: the English Metric Unit (EMU). ``EMU`` supplies the conversion
constants (914,400 per inch; 12,700 per point) and the standard 16:9 default page size.
``PageGeometry`` converts those raw numbers to `CGRect` / `CGSize` values by reading the
`size` + `transform` fields that the API returns on every `PageElement`.

### Layout matching

``LayoutMatcher`` maps semantic ``SlideContent`` descriptions — title, subtitle, bodies,
table count — to the best-fit `PredefinedLayout`, porting the same rule order that
md2googleslides uses. ``PlaceholderResolver`` walks the Master → Layout → Slide inheritance
chain to fill in missing geometry for slide elements that rely on their layout parent.

### Template and design system

``PresentationTemplate`` expresses an entire deck's design as data: the master page (carrying
a ``ThemeSpec`` color scheme) and, for each predefined layout, the placeholder rectangles and
default text styles as ``PlaceholderSpec`` values. Consumers call `spec(layout:type:index:)`
to retrieve a fully-configured placeholder without embedding any magic numbers.

The design-system types — ``SpacingScale``, ``HeaderStyle``, and ``SlideDesignSystem`` —
bundle vertical-rhythm tokens and header-treatment choices so a caller can swap the whole
look of a deck by changing one value, not by hunting magic constants across layout cases.

``PresentationTypography`` assigns a font family and numeric weight to each semantic role
(title, subtitle, body, eyebrow, big-number, footer). It is applied on top of geometry the
same way ``ThemeSpec`` applies color, and `.system` (all roles unset) is always a safe default.

```swift
import GSlidesLayout

// Infer the best predefined layout for a slide
let content = SlideContent(
    title: .init("Q3 Results"),
    bodies: [.init(text: .init("Revenue grew 42 % YoY"))]
)
let layout = LayoutMatcher.match(content)   // → .titleAndBody

// Build a placeholder spec for that layout's title slot
let spec = PresentationTemplate.spec(
    layout: layout,
    type: .title,
    index: 0,
    typography: .system
)
// spec?.size, spec?.transform — ready to embed in a PageElement
```

## Topics

### Coordinate utilities

- ``EMU``
- ``PageGeometry``

### Placeholder resolution

- ``PlaceholderResolver``
- ``PlaceholderSpec``
- ``PresentationTemplate``

### Layout matching

- ``SlideContent``
- ``LayoutMatcher``

### Design system

- ``SlideDesignSystem``
- ``SpacingScale``
- ``HeaderStyle``

### Color and typography

- ``ThemeSpec``
- ``PresentationTypography``
