# ``GSlidesEdit``

Local batchUpdate execution and validation for Google Slides presentations.

## Overview

GSlidesEdit implements a pure, in-memory mirror of the Slides API's `batchUpdate` endpoint.
It applies the official `Request` vocabulary (from GSlidesRequests) to a ``GSlidesSchema/Presentation``
without making any network calls — the same types the wire speaks, executed locally.

The library enforces the same atomicity guarantee as the real API: **if any request in the batch
is invalid, nothing is applied** and a ``BatchUpdateError`` is thrown listing every
``FieldViolation`` so the caller (or an LLM agent) can fix them all in one pass.

### Edit lifecycle

1. **Decode** — ``GSlidesEditContract/decode(_:)`` parses model output into `[Request]`.
2. **Preflight** — ``PreflightValidator`` collects all violations up front (objectId existence,
   page bounds, enum correctness, field-mask syntax).
3. **Apply** — ``GSlidesSchema/Presentation/applying(_:)`` executes the validated batch atomically.

Use ``GSlidesEditContract`` as the single entry point; it composes the three steps and generates
the JSON Schema + worked examples to teach an LLM the correct request shape.

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
