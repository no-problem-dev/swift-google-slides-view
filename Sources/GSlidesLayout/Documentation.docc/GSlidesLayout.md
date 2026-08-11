# ``GSlidesLayout``

Geometry, layout matching and the slide design system for Google Slides presentations.

## Overview

GSlidesLayout sits between the wire types in `GSlidesSchema` and their consumers — `GSlidesRenderer`,
`GSlidesPrompt` and `GSlidesExport`. It answers two questions the schema leaves open: where does an
element go, and which layout should a slide use.

### Units

Every measurement here is in EMU, the Slides API's native unit, except font sizes, which are in
typographic points. ``EMU`` carries the conversion constants — 914,400 EMU per inch, 12,700 per
point — and the standard 16:9 page size used when a presentation declares none.

``PageGeometry`` reads the `size` + `transform` pair the API returns on every `PageElement` and
produces a `CGRect` in page coordinates, origin top-left, y growing downward. It normalizes a
negative scale into a positive rectangle and **ignores shear**, so a rotated element reports its
pre-rotation box. It returns nil for an element with no size, which is what an unresolved
placeholder looks like — run ``PlaceholderResolver`` first.

### Placeholder inheritance

The API omits `size` and `transform` on a placeholder the author never moved, leaving those values on
the layout page. ``PlaceholderResolver`` walks master → layout → slide and fills them in, matching on
`parentObjectId` when present and on the (type, index) pair otherwise. Only geometry is inherited,
not text style.

### Layout matching

``LayoutMatcher`` maps a semantic ``SlideContent`` description — title, subtitle, bodies, table count
— onto a `PredefinedLayout`, porting the rule order from md2googleslides. The rules are ordered and
the first match wins; nothing matching yields `.blank`.

### Template and design system

``PresentationTemplate`` holds a deck's design as data: a master page carrying a ``ThemeSpec`` color
scheme, and a ``PlaceholderSpec`` rectangle plus default style for every predefined layout slot.
Consumers call `spec(layout:type:index:typography:scale:)` instead of embedding coordinates.

``SpacingScale``, ``HeaderStyle`` and ``SlideDesignSystem`` collect the vertical rhythm tokens and
the header treatment, so changing one value reskins every content slide at once. Header and body
positions are derived from the same scale, which is why a taller header pushes bodies down instead of
overlapping them.

``PresentationTypography`` assigns a font family and numeric weight per semantic role — title,
subtitle, body, eyebrow, big number, footer — and is layered onto the geometry the way ``ThemeSpec``
is layered onto color. It only fills in fields a slot leaves nil, and `.system` sets nothing at all.

```swift
import GSlidesLayout

// Infer the best predefined layout for a slide
let content = SlideContent(
    title: .init("Q3 Results"),
    bodies: [.init(text: .init("Revenue grew 42 % YoY"))]
)
let layout = LayoutMatcher.match(content)   // → .titleAndBody

// Build the placeholder spec for that layout's title slot
let spec = PresentationTemplate.spec(
    layout: layout,
    type: .title,
    index: 0,
    typography: .system
)
// spec?.size and spec?.transform are ready to attach to a PageElement
```

## Topics

### Units and coordinates

- ``EMU``
- ``PageGeometry``

### Placeholder resolution

- ``PlaceholderResolver``

### Layout matching

- ``SlideContent``
- ``LayoutMatcher``

### Template

- ``PresentationTemplate``
- ``PlaceholderSpec``

### Design system

- ``SlideDesignSystem``
- ``SpacingScale``
- ``HeaderStyle``

### Color and typography

- ``ThemeSpec``
- ``PresentationTypography``
