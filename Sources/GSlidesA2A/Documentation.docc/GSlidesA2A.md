# ``GSlidesA2A``

An Agent-to-Agent streaming codec that maps A2A protocol events onto `GSlidesChunk` values.

## Overview

GSlidesA2A bridges the [A2A protocol](https://github.com/google/A2A) and the chunk-based assembly
pipeline in `GSlidesAssembly`. A server that wants to stream a presentation to a client does not
invent a wire format: it emits standard `TaskArtifactUpdateEvent` values with a `DataPart` payload,
and declares two things in artifact metadata — that this is a gslides stream, and what kind of chunk
it carries. Both are extension points the A2A spec already allows, so nothing custom appears on the
wire.

``GSlidesA2AVocabulary`` documents those keys (`gslides.schema` and `gslides.kind`) and the media
type. ``GSlidesArtifactCoding`` is the codec itself: the sender helpers build correctly structured
events from a `Presentation`, a `Page` or a `[Request]`, and the receiver helpers expand an event
into `GSlidesChunk` values ready for `GSlidesAssembler`.

``GSlidesArtifactAssembler`` wraps event filtering, artifact tracking and chunk assembly into one
`apply(_:)` call — the smallest surface a client needs to rebuild a streamed presentation.

### What gets ignored, and when

Filtering is deliberate but silent, so know what it drops:

- An artifact without the `gslides.schema` marker is ignored; `apply(_:)` returns false rather than
  throwing, which is what lets other producers share the stream.
- ``GSlidesArtifactAssembler`` locks onto the first gslides artifact it sees. A second gslides deck
  on the same stream is also ignored.
- When `gslides.kind` is missing, the kind is inferred from the event's `append` flag. That cannot
  tell a batch update from a slide, so a receiver reading an older stream will try to decode edits as
  a page and fail.

A batch update applies atomically: a rejected batch throws and leaves the presentation exactly as it
was, never partly edited.

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

// Receiver — accumulate events until the stream completes
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
