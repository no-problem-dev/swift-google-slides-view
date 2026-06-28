# ``GSlidesA2A``

Agent-to-Agent (A2A) streaming codec that maps A2A protocol events to `GSlidesChunk` values.

## Overview

GSlidesA2A bridges the [A2A protocol](https://github.com/google/A2A) and the chunk-based
assembly pipeline in `GSlidesAssembly`. An A2A server that wants to stream a presentation
to a client does not invent a custom wire format — it emits standard
`TaskArtifactUpdateEvent` values with a `DataPart` payload and two metadata keys that
identify the artifact as a gslides stream and declare its chunk kind.

``GSlidesA2AVocabulary`` documents those keys (`gslides.schema` and `gslides.kind`) and
the media type (`application/json`). ``GSlidesArtifactCoding`` is the codec: its sender-side
helpers (`envelopeEvent`, `slideEvent`, `batchUpdateEvent`) build correctly-structured
events from a `Presentation`, `Page`, or `[Request]`; its receiver-side helpers
(`chunks(from:)`, `presentation(from:)`) unpack events into ``GSlidesAssembly/GSlidesChunk``
values that feed directly into a ``GSlidesAssembly/GSlidesAssembler``.

``GSlidesArtifactAssembler`` is a convenience wrapper that combines event filtering (ignore
non-gslides artifacts), artifact-ID tracking, and chunk assembly into a single `mutating
apply(_:)` call — the minimal surface a client needs to reconstruct a streamed presentation.

```swift
import GSlidesA2A

// Sender — emit one slide at a time
let event = try GSlidesArtifactCoding.slideEvent(
    taskId: taskId,
    contextId: contextId,
    artifactId: "deck",
    page: slide,
    lastChunk: isLast
)

// Receiver — accumulate events until the stream is complete
var receiver = GSlidesArtifactAssembler()
for event in a2aStream {
    try receiver.apply(event)
}
if let presentation = receiver.presentation, receiver.isComplete {
    // hand off to GSlidesRenderer
}
```

## Topics

### Vocabulary

- ``GSlidesA2AVocabulary``

### Codec

- ``GSlidesArtifactCoding``

### Stream assembler

- ``GSlidesArtifactAssembler``

### Errors

- ``GSlidesA2AError``
