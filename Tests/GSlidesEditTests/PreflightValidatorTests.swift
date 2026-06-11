import Foundation
import Testing
import GSlidesSchema
import GSlidesRequests
@testable import GSlidesEdit

/// The preflight rules, each grounded in a constraint from `Resources/Spec/constraints-catalog.yaml`.
/// A 10"×7.5" slide (EMU) with one 100pt×50pt text element at the origin.
@Suite struct PreflightValidatorTests {
    static let pageW = 9_144_000.0  // 10 in
    static let pageH = 6_858_000.0  // 7.5 in

    func presentation() -> Presentation {
        let el = PageElement(
            objectId: "el-1",
            size: Size(width: Dimension(magnitude: 100, unit: .pt), height: Dimension(magnitude: 50, unit: .pt)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
            shape: Shape(shapeType: .textBox, text: TextContent(textElements: [
                TextElement(textRun: TextRun(content: "Hello")),
            ])))
        let slide = Page(objectId: "slide1", pageType: .slide, pageElements: [el])
        return Presentation(title: "t", pageSize: Size(
            width: Dimension(magnitude: Self.pageW, unit: .emu),
            height: Dimension(magnitude: Self.pageH, unit: .emu)), slides: [slide])
    }

    func violations(_ requests: [Request], allowing: Set<String>? = nil) -> [FieldViolation] {
        PreflightValidator.violations(in: requests, against: presentation(), allowing: allowing)
    }

    // MARK: clean

    @Test func cleanBatchHasNoViolations() {
        let v = violations([
            .replaceAllText(ReplaceAllTextRequest(replaceText: "Hi", containsText: SubstringMatchCriteria(text: "Hello"))),
            .updateTextStyle(UpdateTextStyleRequest(objectId: "el-1", style: TextStyle(bold: true), textRange: Range(type: .all), fields: "bold")),
        ])
        #expect(v.isEmpty)
    }

    // MARK: existence (catalog: object-reference-existence)

    @Test func unknownObjectIdReported() {
        let v = violations([.updateTextStyle(UpdateTextStyleRequest(objectId: "ghost", style: TextStyle(bold: true)))])
        #expect(v.first?.reason == .objectNotFound)
        #expect(v.first?.field == "requests[0].updateTextStyle.objectId")
    }

    @Test func missingRequiredFieldReported() {
        let v = violations([.updateTextStyle(UpdateTextStyleRequest(objectId: "el-1"))])  // no style
        #expect(v.contains { $0.reason == .requiredFieldMissing && $0.field.hasSuffix("style") })
    }

    // MARK: object id format + uniqueness (catalog: object-id-format / object-id-uniqueness)

    @Test func invalidNewObjectIdReported() {
        let v = violations([.duplicateObject(DuplicateObjectRequest(objectId: "el-1", objectIds: ["el-1": "x"]))])
        #expect(v.contains { $0.reason == .invalidObjectId })  // "x" too short
    }

    @Test func duplicateNewObjectIdReported() {
        let v = violations([.duplicateObject(DuplicateObjectRequest(objectId: "el-1", objectIds: ["el-1": "el-1"]))])
        #expect(v.contains { $0.reason == .duplicateObjectId })  // collides with existing
    }

    // MARK: oneof (catalog: request-exactly-one-kind)

    @Test func multipleKindsReported() {
        let r = Request(insertText: InsertTextRequest(objectId: "el-1", text: "x"),
                        deleteObject: DeleteObjectRequest(objectId: "el-1"))
        #expect(violations([r]).first?.reason == .multipleKindsInRequest)
    }

    @Test func emptyRequestReported() {
        #expect(violations([Request()]).first?.reason == .emptyRequest)
    }

    // MARK: enum (catalog: enum-values-closed)

    @Test func unknownEnumValueReported() {
        let r = Request(updatePageElementTransform: UpdatePageElementTransformRequest(
            objectId: "el-1",
            transform: AffineTransform(translateX: 1, translateY: 1, unit: .emu),
            applyMode: UpdatePageElementTransformRequestApplyMode(rawValue: "SIDEWAYS")))
        #expect(violations([r]).contains { $0.reason == .unknownEnumValue })
    }

    // MARK: page bounds (catalog: page-bounds — API does NOT enforce this)

    @Test func offPageMoveReported() {
        let r = Request(updatePageElementTransform: UpdatePageElementTransformRequest(
            objectId: "el-1",
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: Self.pageW, translateY: 0, unit: .emu),
            applyMode: .absolute))  // x == page width → entirely off-slide
        #expect(violations([r]).contains { $0.reason == .outOfPageBounds })
    }

    @Test func onPageMoveIsClean() {
        let r = Request(updatePageElementTransform: UpdatePageElementTransformRequest(
            objectId: "el-1",
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 100_000, translateY: 100_000, unit: .emu),
            applyMode: .absolute))
        #expect(violations([r]).isEmpty)
    }

    @Test func degenerateScaleReported() {
        let r = Request(updatePageElementTransform: UpdatePageElementTransformRequest(
            objectId: "el-1",
            transform: AffineTransform(scaleX: 0, scaleY: 1, translateX: 0, translateY: 0, unit: .emu),
            applyMode: .absolute))
        #expect(violations([r]).contains { $0.reason == .degenerateTransform })
    }

    @Test func boundsCheckSkippedWhenPolicyDisabled() {
        let r = Request(updatePageElementTransform: UpdatePageElementTransformRequest(
            objectId: "el-1",
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: Self.pageW, translateY: 0, unit: .emu),
            applyMode: .absolute))
        let v = PreflightValidator.violations(in: [r], against: presentation(),
            policy: .init(rejectOffPage: false, rejectDegenerateScale: false))
        #expect(v.isEmpty)
    }

    // MARK: field mask (catalog: field-mask-semantics)

    @Test func malformedFieldMaskReported() {
        let r = Request(updateTextStyle: UpdateTextStyleRequest(objectId: "el-1", style: TextStyle(bold: true), fields: "*,bold"))
        #expect(violations([r]).contains { $0.reason == .invalidFieldMask })
    }

    @Test func emptyFieldMaskIsAllowed() {
        // Omitting fields is the "update exactly what I set" convention — not a violation.
        let r = Request(updateTextStyle: UpdateTextStyleRequest(objectId: "el-1", style: TextStyle(bold: true)))
        #expect(!violations([r]).contains { $0.reason == .invalidFieldMask })
    }

    // MARK: text range

    @Test func invertedTextRangeReported() {
        let r = Request(deleteText: DeleteTextRequest(objectId: "el-1",
            textRange: Range(startIndex: 5, endIndex: 2, type: .fixedRange)))
        #expect(violations([r]).contains { $0.reason == .invalidTextRange })
    }

    // MARK: policy gates

    @Test func unsupportedOperationReported() {
        #expect(violations([.rerouteLine(RerouteLineRequest(objectId: "el-1"))]).first?.reason == .unsupportedOperation)
    }

    @Test func disallowedOperationReported() {
        let v = violations([.deleteObject(DeleteObjectRequest(objectId: "el-1"))], allowing: ["updateTextStyle"])
        #expect(v.first?.reason == .operationNotPermitted)
    }

    // MARK: SSOT consistency — supportedOperations must cover every curated op (+ createSlide).

    @Test func supportedOperationsCoverCuratedSet() {
        for op in GSlidesEditContract.curatedOperations {
            #expect(GSlidesEditor.supportedOperations.contains(op), "curated op '\(op)' not supported by reducer")
        }
        #expect(GSlidesEditor.supportedOperations.contains("createSlide"))
    }
}
