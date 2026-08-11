# ``GSlidesEdit``

Local batchUpdate execution and validation for Google Slides presentations.

## Overview

GSlidesEdit reproduces the Slides API's `batchUpdate` endpoint in memory. It applies the same
`Request` values that go over the wire to a ``GSlidesSchema/Presentation``, with no network call.

It enforces the API's atomicity guarantee: **if any request in a batch is invalid, nothing is
applied** and a ``BatchUpdateError`` is thrown carrying every ``FieldViolation`` found — not just the
first. That is what lets a caller, or an LLM agent, fix all the problems in one pass instead of one
server round trip per mistake.

### The edit lifecycle

1. **Decode** — ``GSlidesEditContract/decode(_:)`` parses model output into `[Request]`. Structural
   only: it checks the batch parses and is non-empty.
2. **Preflight** — ``PreflightValidator`` collects every violation up front: objectId existence,
   page bounds, enum validity, field-mask syntax, degenerate transforms.
3. **Apply** — ``GSlidesSchema/Presentation/applying(_:)`` runs the validated batch atomically.

Use ``GSlidesEditContract`` as the single entry point: it composes the three steps and also produces
the JSON Schema and worked examples that teach a model the correct request shape.

### What it does not cover

The reducer executes 10 of the API's 44 operations — enough to adjust an existing deck, deliberately
kept small because selection accuracy drops as the operation set grows. Anything outside that set is
reported as an `UNSUPPORTED_OPERATION` violation rather than being silently skipped. Table-cell text
editing is likewise rejected rather than ignored.

Preflight reads the presentation as it is now, not as the batch would leave it. A request referencing
an object an earlier request in the same batch creates is reported as not found.

### Units and coordinates

Transforms are in EMU: 914,400 per inch, 12,700 per point. `translateX` / `translateY` locate an
element's **upper-left** corner, which is what the off-page check measures against. The off-page
check needs a declared page size; a presentation without one skips it.

## Topics

### Entry point

- ``GSlidesEditContract``

### Execution

- ``GSlidesEditor``

### Validation

- ``PreflightValidator``
- ``FieldViolation``
- ``ViolationReason``
- ``BatchUpdateError``

### Inspection

- ``GSlidesPresentationInspector``
- ``PresentationSnapshot``
- ``PresentationElementDescriptor``
