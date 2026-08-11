# ``GSlidesRequests``

Generated Swift types for the Google Slides API `batchUpdate` request vocabulary.

## Overview

GSlidesRequests provides `Codable` request types mirroring the
[Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1). They are
generated from the discovery schema, so the Swift vocabulary cannot drift from the wire vocabulary.

The two entry points are ``BatchUpdatePresentationRequest``, the envelope the API accepts, and
``Request``, the tagged union that is one element of the `requests` array. ``Request`` exposes one
optional field per operation kind and is the interchange format `GSlidesEdit` and `GSlidesAssembly`
work in.

Read ``Request/kind`` rather than testing the optional fields. It returns the first member that is
set, and `.other` when none is — which also covers a member newer than this mirror, whose fields
still survive a decode/encode round trip. Because it reports only the first, `kind` is not a check
that exactly one operation is set; `PreflightValidator` in `GSlidesEdit` enforces that.

Requests are applied in array order, so one may depend on an object an earlier one created.

Enum-like fields — line types, shape types, replace methods, z-order operations — are open-ended
`SpecEnum` structs rather than Swift enums, so a value the API adds later decodes
without a library update.

Every property is optional, including required ones, so a partial or unfamiliar payload decodes
rather than throwing. Validation is a separate step.

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
- ``WriteControl``

### Slide operations

- ``CreateSlideRequest``
- ``DeleteObjectRequest``
- ``DuplicateObjectRequest``
- ``UpdateSlidesPositionRequest``
- ``UpdateSlidePropertiesRequest``
- ``UpdatePagePropertiesRequest``

### Shapes and text

- ``CreateShapeRequest``
- ``InsertTextRequest``
- ``DeleteTextRequest``
- ``ReplaceAllTextRequest``
- ``UpdateTextStyleRequest``
- ``UpdateParagraphStyleRequest``
- ``CreateParagraphBulletsRequest``
- ``DeleteParagraphBulletsRequest``

### Images and media

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
- ``UpdateLineCategoryRequest``
- ``CreateLineRequest``
- ``RerouteLineRequest``
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

### Targeting

- ``Range``
- ``RangeType``
- ``PageElementProperties``
