import Foundation
import GSlidesRequests
import GSlidesSchema

/// 何かが適用される前に公式 `Request` のバッチを現在の `Presentation` に対して検証する —
/// discovery doc が記述するサーバーサイドチェックのローカルミラー（「各リクエストは適用前に
/// 検証される。いずれかのリクエストが無効な場合、リクエスト全体が失敗し何も適用されない」、catalog: batch-atomicity）。
///
/// 見つかったすべてのバイオレーションを返す純粋関数（最初のバイオレーションでスローしない）なので、
/// エージェントは 1 パスで全リストを取得し、再送前にバッチ全体を修正できる —
/// N 回のサーバー往復拒否を 1 回のローカル判定に変換する。ルールは
/// `Resources/Spec/constraints-catalog.yaml` を根拠とし、各チェックが強制するカタログ ID を名付ける。
public enum PreflightValidator {
    /// API 自体は実行しない Tier-B（呼び出し元強制）チェックのオプションのしきい値。
    public struct Policy: Sendable {
        /// 要素をスライド完全外に移動させるトランスフォームを拒否する。(catalog: page-bounds)
        public var rejectOffPage: Bool
        /// scaleX または scaleY が正確に 0 のトランスフォームを拒否する。(catalog: degenerate-transform)
        public var rejectDegenerateScale: Bool

        public init(rejectOffPage: Bool = true, rejectDegenerateScale: Bool = true) {
            self.rejectOffPage = rejectOffPage
            self.rejectDegenerateScale = rejectDegenerateScale
        }

        public static let `default` = Policy()
    }

    /// `requests` 内のすべてのフィールドバイオレーション（バッチ順）。空なら適用しても安全。
    public static func violations(
        in requests: [Request],
        against presentation: Presentation,
        allowing allowed: Set<String>? = nil,
        policy: Policy = .default
    ) -> [FieldViolation] {
        let index = PresentationIndex(presentation)
        var out: [FieldViolation] = []
        for (i, request) in requests.enumerated() {
            out.append(contentsOf: violations(in: request, at: i, index: index, allowing: allowed, policy: policy))
        }
        return out
    }

    static func violations(
        in request: Request, at i: Int, index: PresentationIndex,
        allowing allowed: Set<String>?, policy: Policy
    ) -> [FieldViolation] {
        let members = setMemberNames(of: request)
        // (catalog: request-exactly-one-kind) — the union must set exactly one sub-request.
        if members.isEmpty {
            return [FieldViolation(field: "requests[\(i)]",
                description: "Request has no operation set; each request must set exactly one operation.",
                reason: .emptyRequest)]
        }
        if members.count > 1 {
            return [FieldViolation(field: "requests[\(i)]",
                description: "Request sets multiple operations (\(members.joined(separator: ", "))); set exactly one.",
                reason: .multipleKindsInRequest)]
        }
        let op = members[0]
        if let allowed, !allowed.contains(op) {
            return [FieldViolation(field: "requests[\(i)].\(op)",
                description: "Operation '\(op)' is not permitted in this edit session.",
                reason: .operationNotPermitted)]
        }
        guard GSlidesEditor.supportedOperations.contains(op) else {
            return [FieldViolation(field: "requests[\(i)].\(op)",
                description: "Operation '\(op)' is not supported by the local edit engine.",
                reason: .unsupportedOperation)]
        }
        let v = Field(op: op)
        return checkKind(request.kind, v: v, index: index, policy: policy).map { $0.prefixed(byRequestIndex: i) }
    }

    // MARK: - Per-operation checks (field paths are request-relative; the caller prefixes the index)

    static func checkKind(_ kind: Request.Kind, v: Field, index: PresentationIndex, policy: Policy) -> [FieldViolation] {
        switch kind {
        case .deleteObject(let r):
            return requireExistingTarget(r.objectId, v: v, index: index, allowSlide: true)

        case .updatePageElementTransform(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            if r.transform == nil {
                out.append(v.missing("transform"))
            }
            out += enumViolation(r.applyMode, v.path("applyMode"))
            if let t = r.transform {
                out += enumViolation(t.unit, v.path("transform.unit"))
                if policy.rejectDegenerateScale, t.scaleX == 0 || t.scaleY == 0 {
                    out.append(FieldViolation(field: v.path("transform"),
                        description: "scaleX/scaleY of 0 collapses the element to zero size.",
                        reason: .degenerateTransform))
                }
                if policy.rejectOffPage, let id = r.objectId,
                   let box = index.resultingBox(ofElement: id, after: t, mode: r.applyMode),
                   let page = index.pageSizeEmu, box.isEntirelyOutside(width: page.w, height: page.h) {
                    out.append(FieldViolation(field: v.path("transform"),
                        description: "The element would be moved entirely off the slide "
                            + "(\(box.describe()) vs page \(Int(page.w))x\(Int(page.h)) EMU).",
                        reason: .outOfPageBounds))
                }
            }
            return out

        case .updatePageElementsZOrder(let r):
            guard let ids = r.pageElementObjectIds, !ids.isEmpty else {
                return [v.missing("pageElementObjectIds")]
            }
            var out = enumViolation(r.operation, v.path("operation"))
            for (j, id) in ids.enumerated() where !index.elementExists(id) {
                out.append(FieldViolation(field: v.path("pageElementObjectIds[\(j)]"),
                    description: "No page element with objectId '\(id)' exists.", reason: .objectNotFound))
            }
            return out

        case .duplicateObject(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            for (key, newId) in (r.objectIds ?? [:]).sorted(by: { $0.key < $1.key }) {
                out += newIdViolations(newId, at: v.path("objectIds.\(key)"), index: index)
            }
            return out

        case .createSlide(let r):
            if let id = r.objectId { return newIdViolations(id, at: v.path("objectId"), index: index) }
            return []

        case .replaceAllText(let r):
            var out: [FieldViolation] = []
            if (r.containsText?.text ?? "").isEmpty { out.append(v.missing("containsText.text")) }
            for (j, page) in (r.pageObjectIds ?? []).enumerated() where !index.slideExists(page) {
                out.append(FieldViolation(field: v.path("pageObjectIds[\(j)]"),
                    description: "No slide with objectId '\(page)' exists.", reason: .objectNotFound))
            }
            return out

        case .insertText(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            if (r.text ?? "").isEmpty { out.append(v.missing("text")) }
            if r.cellLocation != nil { out.append(v.unsupported("cellLocation", "table-cell text")) }
            if let idx = r.insertionIndex, idx < 0 {
                out.append(FieldViolation(field: v.path("insertionIndex"),
                    description: "insertionIndex must be >= 0.", reason: .invalidTextRange))
            }
            return out

        case .deleteText(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            if r.cellLocation != nil { out.append(v.unsupported("cellLocation", "table-cell text")) }
            out += rangeViolations(r.textRange, at: v.path("textRange"))
            return out

        case .updateTextStyle(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            if r.style == nil { out.append(v.missing("style")) }
            if r.cellLocation != nil { out.append(v.unsupported("cellLocation", "table-cell text")) }
            out += fieldMaskViolations(r.fields, at: v.path("fields"))
            out += rangeViolations(r.textRange, at: v.path("textRange"))
            return out

        case .updateShapeProperties(let r):
            var out = requireExistingElement(r.objectId, v: v, index: index)
            if r.shapeProperties == nil { out.append(v.missing("shapeProperties")) }
            out += fieldMaskViolations(r.fields, at: v.path("fields"))
            return out

        default:
            return []  // unreachable: unsupported ops are filtered before this point
        }
    }

    // MARK: - Reusable checks

    static func requireExistingElement(_ objectId: String?, v: Field, index: PresentationIndex) -> [FieldViolation] {
        guard let id = objectId, !id.isEmpty else { return [v.missing("objectId")] }
        return index.elementExists(id) ? [] : [v.notFound(id, kind: "page element")]
    }

    static func requireExistingTarget(_ objectId: String?, v: Field, index: PresentationIndex, allowSlide: Bool) -> [FieldViolation] {
        guard let id = objectId, !id.isEmpty else { return [v.missing("objectId")] }
        if index.elementExists(id) || (allowSlide && index.slideExists(id)) { return [] }
        return [v.notFound(id, kind: allowSlide ? "page element or slide" : "page element")]
    }

    /// ユーザー指定の新規オブジェクト ID：フォーマット規則に合致し衝突しないこと。(catalog: object-id-format, object-id-uniqueness)
    static func newIdViolations(_ id: String, at path: String, index: PresentationIndex) -> [FieldViolation] {
        var out: [FieldViolation] = []
        if !GSlidesSpec.ObjectId.isValid(id) {
            out.append(FieldViolation(field: path,
                description: "Object ID '\(id)' is invalid: must start with [a-zA-Z0-9_], then "
                    + "[a-zA-Z0-9_-:], length 5–50.", reason: .invalidObjectId))
        }
        if index.exists(id) {
            out.append(FieldViolation(field: path,
                description: "Object ID '\(id)' already exists; IDs must be unique across all pages "
                    + "and page elements.", reason: .duplicateObjectId))
        }
        return out
    }

    /// discovery doc が定義しない値にデコードされた enum フィールド。(catalog: enum-values-closed)
    static func enumViolation<E: SpecEnum>(_ value: E?, _ path: String) -> [FieldViolation] {
        guard let value, !value.isKnown else { return [] }
        return [FieldViolation(field: path,
            description: "'\(value.rawValue)' is not a valid value; allowed: "
                + E.knownValues.map(\.rawValue).joined(separator: ", ") + ".",
            reason: .unknownEnumValue)]
    }

    /// `fields` マスクの整形式検査。(catalog: field-mask-semantics) — 空マスクは許可（リデューサーが
    /// パッチのキーから推論）；`*` は単独でなければならない；空のパストークンは不可。
    static func fieldMaskViolations(_ fields: String?, at path: String) -> [FieldViolation] {
        guard let fields, !fields.isEmpty else { return [] }
        let tokens = fields.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if tokens.contains(where: \.isEmpty) {
            return [FieldViolation(field: path,
                description: "Field mask '\(fields)' has an empty path segment.", reason: .invalidFieldMask)]
        }
        if tokens.contains("*"), tokens.count > 1 {
            return [FieldViolation(field: path,
                description: "Field mask '*' (all fields) must not be combined with other paths.",
                reason: .invalidFieldMask)]
        }
        return []
    }

    /// 反転または負のテキスト範囲。（長さはここでは不明；リデューサーが実際のテキストにクランプする —
    /// preflight は構造的に不可能なものだけを拒否する。）
    static func rangeViolations(_ range: GSlidesRequests.Range?, at path: String) -> [FieldViolation] {
        guard let range else { return [] }
        let start = range.startIndex ?? 0
        switch range.type ?? .all {
        case .fixedRange:
            let end = range.endIndex ?? 0
            if start < 0 || end < start {
                return [FieldViolation(field: path,
                    description: "Invalid FIXED_RANGE [\(start), \(end)): start must be >= 0 and <= end.",
                    reason: .invalidTextRange)]
            }
        case .fromStartIndex:
            if start < 0 {
                return [FieldViolation(field: path,
                    description: "FROM_START_INDEX startIndex must be >= 0 (got \(start)).",
                    reason: .invalidTextRange)]
            }
        default:
            break  // ALL — no indices
        }
        return []
    }

    // MARK: - Request introspection

    /// `request` に実際にセットされているすべてのサブリクエスト名（`kind` ユニオンメンバー）。
    /// 「正確に 1 件」を強制するために使う。データ駆動なので 44 メンバーユニオンから乖離しない。
    static func setMemberNames(of request: Request) -> [String] {
        var names: [String] = []
        for child in Mirror(reflecting: request).children {
            if let label = child.label,
               Mirror(reflecting: child.value).displayStyle == .optional,
               Mirror(reflecting: child.value).children.first != nil {
                names.append(label)
            }
        }
        return names
    }
}

/// 1 オペレーションに対してリクエスト相対フィールドパスを構築する小さなヘルパー。例: `Field(op: "insertText").path("text")` → `"insertText.text"`。
struct Field {
    let op: String
    func path(_ sub: String) -> String { "\(op).\(sub)" }
    func missing(_ sub: String) -> FieldViolation {
        FieldViolation(field: path(sub), description: "Required field '\(sub)' is missing.",
                       reason: .requiredFieldMissing)
    }
    func notFound(_ id: String, kind: String) -> FieldViolation {
        FieldViolation(field: path("objectId"), description: "No \(kind) with objectId '\(id)' exists.",
                       reason: .objectNotFound)
    }
    func unsupported(_ sub: String, _ what: String) -> FieldViolation {
        FieldViolation(field: path(sub), description: "\(what) editing is not supported.",
                       reason: .unsupportedOperation)
    }
}
