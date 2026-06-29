import Foundation
import GSlidesRequests
import GSlidesSchema

/// 編集ループのコントラクト。編集エージェントは **公式 batchUpdate リクエスト** — ワイヤーと
/// リデューサーがすでに使う `Request` 型のキュレーション済みサブセット — を emit してプレゼンテーション
/// を精製する。独自のボキャブラリーは使わない。これにより単一の信頼情報源を維持し
/// （並行する編集言語の乖離がない）、実際のエージェント編集システム（Figma / Docs / Office は
/// 具体的な API ops を emit する）と同じ方式を採用し、型付きでテスト済みのリクエストモデルを再利用する。
/// スキーマ＋作業済み例が形状を教える。
///
/// フローは **decode → preflight → アトミック apply** — 実際の API に忠実：バッチ全体を事前検証
/// （`PreflightValidator`）し、問題があれば何も適用せず、すべての `FieldViolation` を持つ
/// `BatchUpdateError` をスローする。エージェントはサーバー往復なしに 1 パスですべてを修正する（`promptFeedback`）。
///
/// `allowing:` で提供するオペレーションをサブセットに制限できる（例: "delete" を無効化）：
/// スキーマ・例・プロンプトすべてが絞り込まれ、禁止オペレーションを使うリクエストは
/// `OPERATION_NOT_PERMITTED` バイオレーションとして報告される。
public enum GSlidesEditContract {
    /// 編集のために提供する 44 batchUpdate オペレーションのキュレーション済みサブセット — 既存の
    /// プレゼンテーションを調整するもの。意図的に小さく保つ（オペレーションセットが大きすぎると選択精度が落ちる）。
    public static let curatedOperations = [
        "updatePageElementTransform",   // move / resize an element
        "updateTextStyle",              // bold / italic / color / size of text
        "updateShapeProperties",        // fill / outline of a shape
        "replaceAllText",               // find & replace text across the presentation
        "insertText",                   // insert text into an element
        "deleteText",                   // delete a text range
        "deleteObject",                 // remove an element (or slide)
        "duplicateObject",              // copy an element
        "updatePageElementsZOrder",     // bring to front / send to back
    ]

    /// キュレーション済みオペレーション 1 件につき 1 つの作業例 — 公式ワイヤー形式そのままのもの。
    /// エージェントが照合するための教材（`allowing:` で許可された形状のみ表示することもできる）。
    public static let operationExamples: [String: String] = [
        "updatePageElementTransform": #"{"updatePageElementTransform":{"objectId":"<id>","applyMode":"RELATIVE","transform":{"scaleX":1,"scaleY":1,"translateX":457200,"translateY":-228600,"unit":"EMU"}}}"#,
        "updateTextStyle": #"{"updateTextStyle":{"objectId":"<id>","style":{"bold":true,"foregroundColor":{"opaqueColor":{"rgbColor":{"red":0.86,"green":0.15,"blue":0.15}}}},"fields":"bold,foregroundColor","textRange":{"type":"ALL"}}}"#,
        "updateShapeProperties": #"{"updateShapeProperties":{"objectId":"<id>","shapeProperties":{"shapeBackgroundFill":{"solidFill":{"color":{"rgbColor":{"red":0.10,"green":0.11,"blue":0.13}}}}},"fields":"shapeBackgroundFill.solidFill.color"}}"#,
        "replaceAllText": #"{"replaceAllText":{"containsText":{"text":"Old title","matchCase":false},"replaceText":"New title"}}"#,
        "insertText": #"{"insertText":{"objectId":"<id>","text":"New text","insertionIndex":0}}"#,
        "deleteText": #"{"deleteText":{"objectId":"<id>","textRange":{"type":"ALL"}}}"#,
        "deleteObject": #"{"deleteObject":{"objectId":"<id>"}}"#,
        "duplicateObject": #"{"duplicateObject":{"objectId":"<id>"}}"#,
        "updatePageElementsZOrder": #"{"updatePageElementsZOrder":{"pageElementObjectIds":["<id>"],"operation":"BRING_TO_FRONT"}}"#,
    ]

    /// 実際に提供するキュレーション済みオペレーション。`allowed` で絞り込む（nil = すべて）。順序は保持する。
    public static func offeredOperations(allowing allowed: Set<String>? = nil) -> [String] {
        curatedOperations.filter { allowed?.contains($0) ?? true }
    }

    // MARK: - Decode → preflight → atomic apply

    /// 公式バッチの構造デコード＋空チェック。`{"requests":[…]}` または裸の `[…]` を受け付ける。
    /// 不正な JSON または空バッチの場合に `BatchUpdateError`（HTTP 400）をスローする —
    /// 実際の API が返すのと同じ形状なので、ホストはそのままエージェントに中継できる。
    public static func decode(_ data: Data) throws -> [Request] {
        let decoded: [Request]
        do {
            if let batch = try? JSONDecoder().decode(BatchUpdatePresentationRequest.self, from: data),
               let r = batch.requests {
                decoded = r
            } else {
                decoded = try JSONDecoder().decode([Request].self, from: data)
            }
        } catch {
            throw BatchUpdateError.invalidJSON(String(describing: error))
        }
        guard !decoded.isEmpty else {
            throw BatchUpdateError.invalidArgument([FieldViolation(
                field: "requests", description: "The batch must contain at least one request.",
                reason: .requiredFieldMissing)])
        }
        return decoded
    }

    /// `presentation` に対してデコード＋完全 preflight を実行する。バッチが安全に適用できる場合は
    /// 検証済みリクエストを返す。問題があれば **すべて** のバイオレーションを列挙した
    /// `BatchUpdateError` をスローする（何も適用しない）。
    @discardableResult
    public static func validate(
        _ data: Data, against presentation: Presentation,
        allowing allowed: Set<String>? = nil, policy: PreflightValidator.Policy = .default
    ) throws -> [Request] {
        let requests = try decode(data)
        let violations = PreflightValidator.violations(
            in: requests, against: presentation, allowing: allowed, policy: policy)
        if !violations.isEmpty { throw BatchUpdateError.invalidArgument(violations) }
        return requests
    }

    /// 検証済みエンドツーエンドパス：モデル出力バイト → 公式リクエスト → 更新済みプレゼンテーション。
    /// **アトミック**：preflight がバイオレーションを発見した場合、バッチ全体を拒否し、
    /// `presentation` はスローされたエラーを通じて変更なしで返される — 何も部分適用しない（catalog: batch-atomicity）。
    public static func apply(
        _ data: Data, to presentation: Presentation,
        allowing allowed: Set<String>? = nil, policy: PreflightValidator.Policy = .default
    ) throws -> Presentation {
        let requests = try validate(data, against: presentation, allowing: allowed, policy: policy)
        return try presentation.applying(requests)
    }

    /// 拒否されたバッチへの LLM 向けフィードバック：API 形式のエラー JSON と、列挙されたすべての
    /// バイオレーションを修正して再送するよう指示する短文。自己修正を促すためエージェントに返す。
    public static func promptFeedback(for error: BatchUpdateError) -> String {
        """
        ### EDIT REJECTED (nothing was applied — the batch is atomic):
        \(error.wireJSON())

        Fix EVERY fieldViolation above (each `field` is a path into your requests array) and resend
        the corrected batch. Do not resend the un-fixed requests.
        """
    }

    // MARK: - Request introspection

    /// リクエストのワイヤーオペレーション名（その単一セットメンバー）。存在しない場合は nil —
    /// ホストがオペレーション別にリクエストをラベル付けまたはフィルタリングできるよう public にしている。
    public static func operationName(of request: Request) -> String? {
        for child in Mirror(reflecting: request).children {
            if let name = child.label, Mirror(reflecting: child.value).children.first != nil {
                return name
            }
        }
        return nil
    }

    // MARK: - LLM teaching material (schema + examples + constraints)

    /// ツール引数の JSON Schema：`{ "requests": [ <キュレーション済み batchUpdate リクエスト 1 件> … ] }`。
    /// アイテム形状は意図的に寛容（リクエスト 1 件につき 1 キー、ワイヤーユニオンをミラー）；
    /// オペレーションリスト＋作業済み EXAMPLES が正確な形状を伝える。
    public static func jsonSchema(allowing allowed: Set<String>? = nil) -> [String: Any] {
        let ops = offeredOperations(allowing: allowed)
        return [
            "type": "object",
            "properties": [
                "requests": [
                    "type": "array",
                    "minItems": 1,
                    "description":
                        "Edits to apply IN ORDER, each an official Google Slides batchUpdate request "
                        + "(exactly one of: \(ops.joined(separator: ", "))). "
                        + "Reference elements by the objectId from inspect_presentation. EMU units: 914400 = 1 inch. "
                        + "Colors are rgbColor with red/green/blue in 0..1. For update* requests you may "
                        + "omit `fields` to update exactly the attributes you set. See the EXAMPLES.",
                    "items": ["type": "object"],
                ],
            ],
            "required": ["requests"],
            "additionalProperties": false,
        ]
    }

    public static func jsonSchemaData(allowing allowed: Set<String>? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonSchema(allowing: allowed), options: [.sortedKeys])
    }

    /// 作業例（提供するオペレーションのみ）を `{"requests":[…]}` エンベロープでラップしたもの。
    public static func examplesJSON(allowing allowed: Set<String>? = nil) -> String {
        let items = offeredOperations(allowing: allowed)
            .compactMap { operationExamples[$0] }
            .joined(separator: ",\n  ")
        return "{\"requests\":[\n  \(items)\n]}"
    }

    /// バリデーターが強制するハード制約。エージェントが拒否から学ぶのではなく最初から正しく
    /// 編集できるよう提示する。`constraints-catalog.yaml` を根拠とする。
    public static let constraintRules = """
    ### EDIT RULES (enforced — a violation rejects the WHOLE batch, applying nothing):
    - Reference only objectIds that exist in the current presentation (from inspect_presentation).
    - Each request sets exactly ONE operation.
    - Coordinates are EMU (914400 = 1 inch; 12700 = 1 point); translateX/Y is the element's
      UPPER-LEFT corner. Keep elements on the slide — do not move them entirely off-page.
    - Do not use scaleX/scaleY of 0 (it makes the element vanish).
    - Enum fields accept only their documented values; rgbColor components are 0..1.
    - In `fields`, list exactly the attributes you set; use "*" alone (never mixed with paths).
    """

    /// システム指示ブロック：ルール（何が強制されるか）＋スキーマ（何が許可されるか）＋作業済み例。
    public static func promptBlock(allowing allowed: Set<String>? = nil) -> String {
        let schema = (try? jsonSchemaData(allowing: allowed)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        \(constraintRules)

        ### EDIT SCHEMA:
        The `requests_json` argument MUST validate against this JSON Schema:
        \(schema)

        ### EDIT EXAMPLES (official batchUpdate shape — match this):
        \(examplesJSON(allowing: allowed))
        """
    }
}
