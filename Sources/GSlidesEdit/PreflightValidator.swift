import Foundation
import GSlidesRequests
import GSlidesSchema

/// Checks a batch of official requests before anything is applied.
///
/// A local mirror of the server-side checks the discovery document describes.
///
/// "Each request is validated before applying it. If any request is not valid, then the entire
/// request will fail and nothing will be applied" (catalog: batch-atomicity).
///
/// Pure, and it returns every violation it finds rather than throwing on the first, so an agent gets
/// the whole list in one pass and can fix the batch before resending — turning N rejected round
/// trips into one local verdict. Rules are sourced from `Resources/Spec/constraints-catalog.yaml`
/// and each check names the catalog ID it enforces.
public enum PreflightValidator {
    /// Thresholds for the checks the API does not perform itself and the caller must opt into.
    public struct Policy: Sendable {
        /// Reject a transform that would move an element entirely off the slide.
        ///
        /// Only enforceable when the presentation declares a page size; without one the check is
        /// skipped, not failed. (catalog: page-bounds)
        public var rejectOffPage: Bool
        /// Reject a transform whose scaleX or scaleY is exactly 0, which collapses the element to
        /// nothing. (catalog: degenerate-transform)
        public var rejectDegenerateScale: Bool

        public init(rejectOffPage: Bool = true, rejectDegenerateScale: Bool = true) {
            self.rejectOffPage = rejectOffPage
            self.rejectDegenerateScale = rejectDegenerateScale
        }

        public static let `default` = Policy()
    }

    /// Every field violation in the batch, in request order. An empty result means it is safe to apply.
    ///
    /// Each request is checked against the presentation as it is now, not as the batch would leave
    /// it, so a request that references an object an earlier request in the same batch creates is
    /// reported as not found.
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

    /// Checks a caller-supplied new object ID against both the format rule and the existing IDs.
    /// (catalog: object-id-format, object-id-uniqueness)
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

    /// Flags an enum field holding a value the pinned discovery document does not define, and lists
    /// the allowed values in the message. (catalog: enum-values-closed)
    static func enumViolation<E: SpecEnum>(_ value: E?, _ path: String) -> [FieldViolation] {
        guard let value, !value.isKnown else { return [] }
        return [FieldViolation(field: path,
            description: "'\(value.rawValue)' is not a valid value; allowed: "
                + E.knownValues.map(\.rawValue).joined(separator: ", ") + ".",
            reason: .unknownEnumValue)]
    }

    /// Checks that a `fields` mask is well formed. (catalog: field-mask-semantics)
    ///
    /// An empty mask is allowed — the reducer infers it from the patch's keys. A `*` must stand
    /// alone, and no token may be empty. Path *names* are not checked against the target type, so a
    /// mask naming a field that does not exist passes here and simply matches nothing.
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

    /// Flags a text range that is inverted or negative.
    ///
    /// The text length is not known here, so a range past the end of the text is not a violation —
    /// the reducer clamps it. Preflight rejects only what is structurally impossible.
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

    /// Every sub-request name actually set on the request — the members of the `kind` union.
    ///
    /// Used to enforce "exactly one". Found by reflection rather than a switch, so it cannot drift
    /// from the 44-member union as the mirror is regenerated.
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

/// Builds request-relative field paths for one operation: `Field(op: "insertText").path("text")`
/// gives `"insertText.text"`. The batch index is prefixed later by the caller.
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
