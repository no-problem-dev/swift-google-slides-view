# ``GSlidesRequests``

Generated Swift types for the Google Slides API `batchUpdate` request vocabulary.

## Overview

GSlidesRequests provides the complete set of `Codable` request types that mirror the
[Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1).
Every type is generated from the discovery schema, so the Swift vocabulary can never
drift from the wire protocol.

The top-level entry points are ``BatchUpdatePresentationRequest`` (the envelope the API
receives) and ``Request`` (the tagged union that wraps exactly one operation per element
of the `requests` array). ``Request`` exposes one optional field per operation kind;
`GSlidesEdit` and `GSlidesAssembly` use it as their interchange format.

Enum-like fields (line categories, shape types, replace methods, z-order operations, etc.)
are modelled as open-ended ``GSlidesSchema/SpecEnum`` structs — not Swift enums — so future
API values decode losslessly without a library update.

```swift
import GSlidesRequests

// Build a batchUpdate that inserts text into a shape
let batch = BatchUpdatePresentationRequest(requests: [
    Request(insertText: InsertTextRequest(
        objectId: "my-shape-id",
        text: "Hello, Slides!",
        insertionIndex: 0
    ))
])
```

## Topics

### Batch container

- ``BatchUpdatePresentationRequest``
- ``Request``

### Slide operations

- ``CreateSlideRequest``
- ``DeleteObjectRequest``
- ``DuplicateObjectRequest``
- ``UpdateSlidesPositionRequest``
- ``UpdatePagePropertiesRequest``

### Shape and text

- ``CreateShapeRequest``
- ``InsertTextRequest``
- ``DeleteTextRequest``
- ``ReplaceAllTextRequest``
- ``UpdateTextStyleRequest``
- ``UpdateParagraphStyleRequest``
- ``CreateParagraphBulletsRequest``
- ``DeleteParagraphBulletsRequest``

### Image and media

- ``CreateImageRequest``
- ``CreateVideoRequest``
- ``ReplaceImageRequest``
- ``ReplaceAllShapesWithImageRequest``
- ``CreateSheetsChartRequest``
- ``ReplaceAllShapesWithSheetsChartRequest``
- ``RefreshSheetsChartRequest``

### Geometry and properties

- ``UpdatePageElementTransformRequest``
- ``UpdateShapePropertiesRequest``
- ``UpdateImagePropertiesRequest``
- ``UpdateVideoPropertiesRequest``
- ``UpdateLinePropertiesRequest``
- ``CreateLineRequest``
- ``UpdatePageElementAltTextRequest``
- ``UpdatePageElementsZOrderRequest``

### Table operations

- ``CreateTableRequest``
- ``InsertTableRowsRequest``
- ``InsertTableColumnsRequest``
- ``DeleteTableRowRequest``
- ``DeleteTableColumnRequest``
- ``MergeTableCellsRequest``
- ``UnmergeTableCellsRequest``
- ``UpdateTableCellPropertiesRequest``
- ``UpdateTableBorderPropertiesRequest``
- ``UpdateTableColumnPropertiesRequest``
- ``UpdateTableRowPropertiesRequest``

### Grouping

- ``GroupObjectsRequest``
- ``UngroupObjectsRequest``
