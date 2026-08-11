# ``GSlidesAssembly``

A pure reducer that builds a streaming `Presentation` from a sequence of typed chunks.

## Overview

GSlidesAssembly is the transport-independent receiving end of the streaming pipeline. It knows
nothing about A2A, HTTP or any other protocol — an adapter maps its protocol's events onto
``GSlidesChunk``, and this library folds them into a presentation.

A chunk carries one of three payload shapes:

- **envelope** — a whole `Presentation`. Replaces the existing state.
- **slide** — a single `Page`, appended to `slides`. Arriving before any envelope creates an empty
  presentation to append to, so a slides-first stream assembles cleanly.
- **batchUpdate** — a `BatchUpdatePresentationRequest` from `GSlidesRequests`, applied atomically to
  the current state through the local executor in `GSlidesEdit`.

``GSlidesAssembler`` is the reducer: a `mutating` value type where each `apply(_:)` advances the
state by exactly one chunk. A chunk with `lastChunk == true` seals the stream, after which envelope
and slide chunks are refused with ``GSlidesAssemblyError/chunkAfterCompletion``. Batch updates are
still accepted after completion — an agent adjusting a finished presentation should not be silently
dropped.

### Failure behavior

Nothing is half-applied. A payload that fails to decode, or a batch the local executor rejects,
throws ``GSlidesAssemblyError/invalidPayload(_:)`` and leaves the presentation exactly as it was.
That case carries a *description* of the underlying error, not the error itself, so a rejected
batch's individual field violations are not recoverable through this API — validate with
`GSlidesEdit`'s preflight before streaming if you need them.

`assemble(_:)` folds an entire sequence in one call. It does not require the sequence to end in a
`lastChunk`, so a truncated stream yields whatever assembled rather than an error.

```swift
import GSlidesAssembly

var assembler = GSlidesAssembler()

// Feed chunks as they arrive from the stream
for event in stream {
    try assembler.apply(event)
}

if let presentation = assembler.presentation, assembler.isComplete {
    // ready to render
}

// Or fold a whole sequence at once
let presentation = try GSlidesAssembler.assemble(chunks)
```

## Topics

### Chunk primitive

- ``GSlidesChunk``

### Reducer

- ``GSlidesAssembler``

### Errors

- ``GSlidesAssemblyError``
