# ``GSlidesRequests``

Google Slides API `batchUpdate` リクエスト語彙の生成済み Swift 型。

## Overview

GSlidesRequests は、[Slides API discovery document](https://slides.googleapis.com/$discovery/rest?version=v1) をミラーした `Codable` リクエスト型を提供する。
型は discovery スキーマから生成されるため、Swift の語彙がワイヤーの語彙から乖離することはない。

トップレベルのエントリポイントは ``BatchUpdatePresentationRequest``（API が受け取るエンベロープ）と
``Request``（`requests` 配列の各要素で正確に 1 つのオペレーションをラップするタグ付きユニオン）。
``Request`` はオペレーション種別ごとに 1 つの optional フィールドを公開し、
`GSlidesEdit` と `GSlidesAssembly` がインターチェンジフォーマットとして使用する。

enum ライクなフィールド（ライン種別・シェイプ種別・置換方式・Z オーダーオペレーションなど）は
オープンエンドな ``GSlidesSchema/SpecEnum`` 構造体でモデル化されており、Swift の enum ではない —
将来の API 値もライブラリ更新なしにロスレスでデコードできる。

```swift
import GSlidesRequests

// シェイプにテキストを挿入する batchUpdate を構築する
let batch = BatchUpdatePresentationRequest(requests: [
    Request(insertText: InsertTextRequest(
        objectId: "my-shape-id",
        text: "Hello, Slides!",
        insertionIndex: 0
    ))
])
```

## Topics

### バッチコンテナ

- ``BatchUpdatePresentationRequest``
- ``Request``

### スライドオペレーション

- ``CreateSlideRequest``
- ``DeleteObjectRequest``
- ``DuplicateObjectRequest``
- ``UpdateSlidesPositionRequest``
- ``UpdatePagePropertiesRequest``

### シェイプとテキスト

- ``CreateShapeRequest``
- ``InsertTextRequest``
- ``DeleteTextRequest``
- ``ReplaceAllTextRequest``
- ``UpdateTextStyleRequest``
- ``UpdateParagraphStyleRequest``
- ``CreateParagraphBulletsRequest``
- ``DeleteParagraphBulletsRequest``

### 画像とメディア

- ``CreateImageRequest``
- ``CreateVideoRequest``
- ``ReplaceImageRequest``
- ``ReplaceAllShapesWithImageRequest``
- ``CreateSheetsChartRequest``
- ``ReplaceAllShapesWithSheetsChartRequest``
- ``RefreshSheetsChartRequest``

### ジオメトリとプロパティ

- ``UpdatePageElementTransformRequest``
- ``UpdateShapePropertiesRequest``
- ``UpdateImagePropertiesRequest``
- ``UpdateVideoPropertiesRequest``
- ``UpdateLinePropertiesRequest``
- ``CreateLineRequest``
- ``UpdatePageElementAltTextRequest``
- ``UpdatePageElementsZOrderRequest``

### テーブルオペレーション

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

### グルーピング

- ``GroupObjectsRequest``
- ``UngroupObjectsRequest``
