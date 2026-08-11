# ``GSlidesEdit``

Google Slides プレゼンテーションへのローカル batchUpdate 実行とバリデーション。

## Overview

GSlidesEdit は Slides API の `batchUpdate` エンドポイントを純粋なインメモリで再現する。ネットワーク呼び出しなしで、ワイヤーと同じ型（GSlidesRequests の `Request` ボキャブラリー）を ``GSlidesSchema/Presentation`` に適用する。

本家 API と同じアトミシティ保証を強制する。**バッチ内のいずれかのリクエストが不正であれば何も適用されず**、``BatchUpdateError`` が throw される。エラーには発見されたすべての ``FieldViolation`` が含まれるため、呼び出し側（または LLM エージェント）は 1 パスで全問題を修正できる。

### 編集ライフサイクル

1. **デコード** — ``GSlidesEditContract/decode(_:)`` がモデル出力を `[Request]` へパースする。
2. **Preflight** — ``PreflightValidator`` がすべての違反を事前に収集する（objectId 存在確認・ページ境界・enum 正当性・フィールドマスク構文）。
3. **適用** — ``GSlidesSchema/Presentation/applying(_:)`` がバリデーション済みバッチをアトミックに実行する。

``GSlidesEditContract`` を唯一のエントリーポイントとして使う。3 ステップを合成し、LLM に正しいリクエスト形状を教えるための JSON Schema とワーク済み例も生成する。

## Topics

### エントリーポイント

- ``GSlidesEditContract``

### 実行

- ``GSlidesEditor``

### バリデーション

- ``PreflightValidator``
- ``FieldViolation``
- ``ViolationReason``
- ``BatchUpdateError``

### インスペクション

- ``GSlidesPresentationInspector``
- ``PresentationElementDescriptor``
- ``PresentationSnapshot``
