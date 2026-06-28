# ``GSlidesAssembly``

Pure reducer that assembles a streaming `Presentation` from a sequence of typed chunks.

## Overview

GSlidesAssembly is the protocol-agnostic receiving half of the Swift Google Slides streaming
pipeline. Its central abstraction is the ``GSlidesChunk``, a typed payload envelope that carries
exactly one of three presentation-stream shapes:

- **envelope** — a full `Presentation`; replaces any prior state.
- **slide** — a single `Page`; appended to `slides`. A slide chunk that arrives before any
  envelope creates an implicit empty presentation, so slide-led streams assemble cleanly.
- **batchUpdate** — a `BatchUpdatePresentationRequest` (from `GSlidesRequests`); applied
  atomically to the current state via the local `batchUpdate` executor.

``GSlidesAssembler`` is the reducer: a pure `mutating` value type whose `apply(_:)` advances
the state by one chunk at a time. The stream is sealed when `lastChunk == true`; further
envelope or slide chunks after that point are rejected with
``GSlidesAssemblyError/chunkAfterCompletion``. Post-completion `batchUpdate` chunks are
accepted (an agent tweaking a finished presentation should not be silently ignored).

The convenience static method `assemble(_:)` collapses an entire sequence of chunks in one
call and returns the finished `Presentation` — useful in tests and one-shot pipeline
consumers.

```swift
import GSlidesAssembly

var assembler = GSlidesAssembler()

// Feed chunks as they arrive from a stream
for event in stream {
    try assembler.apply(event)
}

if let presentation = assembler.presentation, assembler.isComplete {
    // Ready to render
}

// Or collapse a sequence at once
let presentation = try GSlidesAssembler.assemble(chunks)
```

## Topics

### Chunk primitive

- ``GSlidesChunk``

### Reducer

- ``GSlidesAssembler``

### Errors

- ``GSlidesAssemblyError``
