# ``GSlidesPrompt``

LLM contracts and the semantic types for generating slides and color themes.

## Overview

GSlidesPrompt defines the boundary between a model and this package: what the model is asked to
emit, and the check that what came back can safely expand into a `Presentation`. Two independent
contracts cover the two structured-output calls.

Validate even when the provider claims to enforce the schema. Provider-side enforcement varies by
model and mode, and an unchecked layout name would reach the expander.

### Generation contract

``GSlidesGenerationContract`` governs slide content. It exposes a JSON Schema for the
``SemanticPresentation`` types — a compact deck representation a model can hold in its head — so the
exact schema can be injected into the system prompt. `validate(_:)` decodes strictly and checks what
the schema cannot express: a non-empty deck, and layout names drawn from the offered vocabulary.
`presentation(from:themeSpec:)` runs the whole path from raw model bytes to a fully expanded
presentation.

The model emits layout intent and content, never geometry. ``PresentationExpander`` supplies the
coordinates from `PresentationTemplate`, which is what makes a generated deck go through the same
layout path as one fetched from the API — and what makes it round-trip back to the API unchanged.

A ``SemanticSlide`` holds ``SemanticBody`` values combining text, bullets, an image URL,
``SemanticMetric`` cards, a ``SemanticChart``, a ``SemanticStep`` flow, a ``SemanticQuote`` or a
``SemanticTable``. The visuals are mutually exclusive with each other and with text: a body carrying
metrics takes over the whole body box, and any text or image on the same body is not drawn. Each
visual is built from native text, shape and line elements, so nothing here needs an external image
service or a chart engine.

When a layout gives a body no geometry, visuals degrade rather than disappear — metrics, charts and
step flows become labeled bullet lists, and a quote becomes plain body text. The information
survives; the picture does not.

### Theme contract

``GSlidesThemeContract`` governs color scheme generation. It exposes a JSON Schema for a
`ColorScheme` restricted to the 12 editable `ThemeColorType` slots, and `promptBlock()`, a
ready-to-paste system-instruction block of rules, schema and a worked example. `themeSpec(from:)`
validates model output and returns a `ThemeSpec` ready to bake into a master page.

All 12 slots are required, each exactly once — JSON Schema can express the count but not the
uniqueness, so validation is what enforces it. Validation reports one failure kind at a time, in the
order unknown types, missing slots, out-of-range components.

### Few-shot examples

The worked examples are built from typed Swift values and serialized, not written by hand. A
hand-written example drifts silently as the schema changes and then teaches the model to emit
something the validator rejects. Serialization is byte-stable, which keeps prompt caching effective.

```swift
import GSlidesPrompt

// --- Slide generation ---
let schemaData = try GSlidesGenerationContract.jsonSchemaData()
let systemPrompt = """
Generate a JSON presentation matching this schema:
\(String(decoding: schemaData, as: UTF8.self))
"""

// Validate model output and expand it into a full Presentation
let presentation = try GSlidesGenerationContract.presentation(from: modelOutputData)

// --- Theme generation ---
let themeInstructions = GSlidesThemeContract.promptBlock()
let themeSpec = try GSlidesThemeContract.themeSpec(from: modelThemeData)
```

## Topics

### Generation contract

- ``GSlidesGenerationContract``
- ``GenerationContractError``

### Theme contract

- ``GSlidesThemeContract``
- ``GSlidesThemeContractError``

### Semantic slide model

- ``SemanticPresentation``
- ``SemanticSlide``
- ``SemanticBody``
- ``SemanticBullet``
- ``SemanticTable``

### Semantic visuals

- ``SemanticMetric``
- ``SemanticChart``
- ``SemanticChartBar``
- ``SemanticStep``
- ``SemanticQuote``

### Expansion and formatting

- ``PresentationExpander``
- ``GSlidesExampleFormatter``
