import Foundation

/// batchUpdate リクエストの 1 フィールドが拒否される理由。`google.rpc.BadRequest.FieldViolation` の
/// `reason` 識別子（SCREAMING_SNAKE_CASE、機械安定）をミラーし、エージェントまたは中継ホストが
/// 散文を解析せずに原因を分岐できるようにする。各 case は `Resources/Spec/constraints-catalog.yaml`
/// の制約にマッピングされる。
public enum ViolationReason: String, Equatable, Sendable, Codable, CaseIterable {
    /// サブリクエストが設定されていない（`kind` ユニオンが空）。(catalog: request-exactly-one-kind)
    case emptyRequest = "EMPTY_REQUEST"
    /// 複数のサブリクエストが設定されている。(catalog: request-exactly-one-kind)
    case multipleKindsInRequest = "MULTIPLE_KINDS_IN_REQUEST"
    /// 必須フィールド（objectId、text、transform など）が欠落している。
    case requiredFieldMissing = "REQUIRED_FIELD_MISSING"
    /// 参照された objectId がプレゼンテーションに存在しない。(catalog: object-reference-existence)
    case objectNotFound = "OBJECT_NOT_FOUND"
    /// ユーザー指定の objectId が文字セット / 長さ規則に違反している。(catalog: object-id-format)
    case invalidObjectId = "INVALID_OBJECT_ID"
    /// ユーザー指定の objectId が既存のものと衝突している。(catalog: object-id-uniqueness)
    case duplicateObjectId = "DUPLICATE_OBJECT_ID"
    /// enum フィールドに discovery document で定義されていない値がある。(catalog: enum-values-closed)
    case unknownEnumValue = "UNKNOWN_ENUM_VALUE"
    /// `fields` マスクが不正（空トークン、または `*` とパスの混在）。(catalog: field-mask-semantics)
    case invalidFieldMask = "INVALID_FIELD_MASK"
    /// テキスト範囲が反転または負の値。
    case invalidTextRange = "INVALID_TEXT_RANGE"
    /// 要素がスライド外に完全に出てしまう。(catalog: page-bounds)
    case outOfPageBounds = "OUT_OF_PAGE_BOUNDS"
    /// トランスフォームが要素を潰す（scaleX または scaleY == 0）。(catalog: degenerate-transform)
    case degenerateTransform = "DEGENERATE_TRANSFORM"
    /// この編集セッションで許可されていないオペレーション（ホストポリシー `allowing:` による）。
    case operationNotPermitted = "OPERATION_NOT_PERMITTED"
    /// ローカルリデューサーが実行しないリクエスト種別（キュレーションサブセット外）。
    case unsupportedOperation = "UNSUPPORTED_OPERATION"
}

/// batchUpdate リクエストを適用できないフィールドレベルの理由 — `google.rpc.BadRequest.FieldViolation`
/// のパッケージミラー。`field` はバッチへのドット区切りパス
/// （例: `requests[2].updatePageElementTransform.objectId`）で、エージェントが問題値を特定し修正できる。
/// `description` は人間 / LLM 向けの説明、`reason` は安定したコード。
public struct FieldViolation: Error, Equatable, Sendable, Codable {
    public var field: String
    public var description: String
    public var reason: ViolationReason

    public init(field: String, description: String, reason: ViolationReason) {
        self.field = field
        self.description = description
        self.reason = reason
    }

    /// このバイオレーションの `field` パスをバッチインデックス配下に付け替える。
    /// 例: `updatePageElementTransform.objectId` → `requests[2].updatePageElementTransform.objectId`。
    /// リデューサーローカルなバイオレーションをバッチ座標に持ち上げるために使用する。
    func prefixed(byRequestIndex index: Int) -> FieldViolation {
        FieldViolation(field: "requests[\(index)].\(field)", description: description, reason: reason)
    }
}

/// batchUpdate が拒否されたときに throw されるエラー — `BadRequest` 詳細を持つ `google.rpc.Status`
/// のパッケージミラー。batchUpdate はアトミックなため（「不正なリクエストが 1 件でもあればバッチ全体が
/// 失敗し何も適用されない」）、拒否されたバッチは何も適用しない。このエラーが発見したすべての
/// フィールドバイオレーションを報告することで、エージェントはサーバー往復なしに 1 パスで全問題を修正できる。
public struct BatchUpdateError: Error, Equatable, Sendable, Codable {
    /// Google がこの種の失敗に返す HTTP スタイルのステータスコード。
    public var code: Int
    /// 標準ステータス文字列（`INVALID_ARGUMENT`、`FAILED_PRECONDITION`）。
    public var status: String
    /// 開発者向けサマリー。
    public var message: String
    /// すべてのフィールドレベルのバイオレーション（`BadRequest.fieldViolations` の詳細）。
    public var fieldViolations: [FieldViolation]

    public init(code: Int, status: String, message: String, fieldViolations: [FieldViolation]) {
        self.code = code
        self.status = status
        self.message = message
        self.fieldViolations = fieldViolations
    }

    /// 空でないバイオレーションリストから `INVALID_ARGUMENT`（HTTP 400）失敗を生成する —
    /// リクエストバリデーション失敗時に Google が返す形式。
    public static func invalidArgument(_ violations: [FieldViolation]) -> BatchUpdateError {
        let summary = violations.count == 1
            ? violations[0].description
            : "\(violations.count) request(s) were invalid; nothing was applied."
        return BatchUpdateError(code: 400, status: "INVALID_ARGUMENT", message: summary,
                                fieldViolations: violations)
    }

    /// 不正なリクエストボディ（有効な JSON でない、またはバッチとして認識できない）。
    /// HTTP 400、フィールドバイオレーションなし — ボディをリクエストとしてパースできなかった。
    public static func invalidJSON(_ detail: String) -> BatchUpdateError {
        BatchUpdateError(code: 400, status: "INVALID_ARGUMENT",
                         message: "Request body is not a valid batchUpdate JSON: \(detail)",
                         fieldViolations: [])
    }

    /// Google のワイヤー JSON（`{"error":{code,status,message,details:[…]}}`）形式でレンダリングした
    /// 完全なエラー。エージェントに自己修正用としてそのまま返すのに適している。
    public func wireJSON() -> String {
        let details: [[String: Any]] = [[
            "@type": "type.googleapis.com/google.rpc.BadRequest",
            "fieldViolations": fieldViolations.map {
                ["field": $0.field, "description": $0.description, "reason": $0.reason.rawValue]
            },
        ]]
        let payload: [String: Any] = ["error": [
            "code": code, "status": status, "message": message, "details": details,
        ]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
        else { return "{\"error\":{\"status\":\"\(status)\",\"message\":\"\(message)\"}}" }
        return String(decoding: data, as: UTF8.self)
    }
}
