# ``GSlidesPrompt``

LLM-facing contracts and semantic types for structured slide generation and theme design.

## Overview

GSlidesPrompt is the "model ↔ package" boundary: it defines what an LLM must emit and
validates that the output is safe to expand into a full `Presentation`. Two independent
contracts handle the two structured-output surfaces.

### Generation contract

``GSlidesGenerationContract`` governs slide content. It exposes a JSON Schema for the
``SemanticPresentation`` type — the compact, model-friendly representation of a deck —
so the exact schema can be injected into the system prompt. The contract's `validate(_:)`
enforces the receiving side of the sandwich: strict decode plus semantic checks (no empty
deck, only known layout names). `presentation(from:themeSpec:)` is the end-to-end path
from raw model bytes to a fully expanded `Presentation`.

``SemanticPresentation`` carries one ``SemanticSlide`` per slide. Each slide may contain
any mix of ``SemanticBody`` (text, bullets, image URL, ``SemanticMetric`` cards,
``SemanticChart``, ``SemanticStep`` flows, ``SemanticQuote``, or ``SemanticTable``), which
``PresentationExpander`` maps to the Slides API's native page elements.

### Theme contract

``GSlidesThemeContract`` governs color scheme generation. It exposes the JSON Schema for
a `ColorScheme` restricted to the 12 editable `ThemeColorType` slots, plus `promptBlock()`
— a ready-made system-instruction block (rules + schema + worked example) to paste directly
into a prompt. `themeSpec(from:)` validates the model's output and returns a ``ThemeSpec``
ready to bake into the master page.

```swift
import GSlidesPrompt

// --- Slide generation ---
let systemPrompt = """
Produce a JSON presentation matching this schema:
\(String(decoding: try GSlidesGenerationContract.jsonSchemaData(), as: UTF8.self))
"""

// Validate and expand model output to a full Presentation
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
- ``SemanticMetric``
- ``SemanticChart``
- ``SemanticChartBar``
- ``SemanticStep``
- ``SemanticQuote``
- ``SemanticTable``

### Expansion and formatting

- ``PresentationExpander``
- ``GSlidesExampleFormatter``
