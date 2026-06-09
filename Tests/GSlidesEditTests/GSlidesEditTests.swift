import Foundation
import Testing
import GSlidesSchema
import GSlidesRequests
@testable import GSlidesEdit

@Suite struct GSlidesEditTests {

    // A one-slide deck with a single text shape ("Hello") at a known transform.
    func deck() -> Presentation {
        let shape = Shape(shapeType: .textBox, text: TextContent(textElements: [
            TextElement(startIndex: 0, endIndex: 5, paragraphMarker: ParagraphMarker(), textRun: TextRun(content: "Hello")),
        ]))
        let element = PageElement(
            objectId: "el-1",
            size: Size(width: Dimension(magnitude: 100, unit: .pt), height: Dimension(magnitude: 50, unit: .pt)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 100, translateY: 200, unit: .emu),
            shape: shape
        )
        let slide = Page(objectId: "slide-1", pageType: .slide, pageElements: [element])
        return Presentation(title: "t", slides: [slide])
    }

    func firstShapeRuns(_ p: Presentation) -> [TextRun] {
        (p.slides?.first?.pageElements?.first?.shape?.text?.textElements ?? []).compactMap(\.textRun)
    }
    func plainText(_ p: Presentation) -> String {
        firstShapeRuns(p).map { $0.content ?? "" }.joined()
    }

    // MARK: structural

    @Test func deleteObjectRemovesElement() throws {
        let out = try deck().applying([.deleteObject(DeleteObjectRequest(objectId: "el-1"))])
        #expect(out.slides?.first?.pageElements?.isEmpty == true)
    }

    @Test func deleteUnknownObjectThrows() {
        #expect(throws: GSlidesEditError.objectNotFound("nope")) {
            _ = try deck().applying([.deleteObject(DeleteObjectRequest(objectId: "nope"))])
        }
    }

    @Test func createSlideInsertsBlankPage() throws {
        let out = try deck().applying([.createSlide(CreateSlideRequest(objectId: "s2", insertionIndex: 0))])
        #expect(out.slides?.count == 2)
        #expect(out.slides?.first?.objectId == "s2")
        #expect(out.slides?.first?.pageType == .slide)
    }

    @Test func duplicateObjectCopiesWithNewId() throws {
        let out = try deck().applying([
            .duplicateObject(DuplicateObjectRequest(objectId: "el-1", objectIds: ["el-1": "el-2"])),
        ])
        let ids = out.slides?.first?.pageElements?.map(\.objectId)
        #expect(ids == ["el-1", "el-2"])
    }

    @Test func zOrderSendToBackMovesFirst() throws {
        var p = deck()
        p.slides?[0].pageElements?.append(PageElement(objectId: "el-9", shape: Shape(shapeType: .rectangle)))
        let out = try p.applying([
            .init(updatePageElementsZOrder: UpdatePageElementsZOrderRequest(
                pageElementObjectIds: ["el-9"], operation: .sendToBack)),
        ])
        #expect(out.slides?.first?.pageElements?.map(\.objectId) == ["el-9", "el-1"])
    }

    // MARK: geometry

    @Test func absoluteTransformReplaces() throws {
        let t = AffineTransform(scaleX: 2, scaleY: 2, translateX: 0, translateY: 0, unit: .emu)
        let out = try deck().applying([
            .updatePageElementTransform(UpdatePageElementTransformRequest(objectId: "el-1", transform: t, applyMode: .absolute)),
        ])
        let xf = out.slides?.first?.pageElements?.first?.transform
        #expect(xf?.translateX == 0 && xf?.scaleX == 2)
    }

    @Test func relativeTransformNudges() throws {
        // A pure translate of +50 / -30, applied relative to translate(100,200) scale 1.
        let nudge = AffineTransform(scaleX: 1, scaleY: 1, translateX: 50, translateY: -30, unit: .emu)
        let out = try deck().applying([
            .updatePageElementTransform(UpdatePageElementTransformRequest(objectId: "el-1", transform: nudge, applyMode: .relative)),
        ])
        let xf = out.slides?.first?.pageElements?.first?.transform
        #expect(xf?.translateX == 150 && xf?.translateY == 170)
    }

    // MARK: text

    @Test func replaceAllTextSubstitutes() throws {
        let out = try deck().applying([
            .replaceAllText(ReplaceAllTextRequest(replaceText: "Goodbye", containsText: SubstringMatchCriteria(text: "Hello"))),
        ])
        #expect(plainText(out) == "Goodbye")
    }

    @Test func insertTextAtIndex() throws {
        let out = try deck().applying([
            .init(insertText: InsertTextRequest(objectId: "el-1", text: "Oh ", insertionIndex: 0)),
        ])
        #expect(plainText(out) == "Oh Hello")
        // Paragraph marker preserved on the (still single) run element.
        #expect(out.slides?.first?.pageElements?.first?.shape?.text?.textElements?.first?.paragraphMarker != nil)
    }

    @Test func deleteTextRange() throws {
        let out = try deck().applying([
            .init(deleteText: DeleteTextRequest(objectId: "el-1",
                textRange: Range(startIndex: 0, endIndex: 2, type: .fixedRange))),
        ])
        #expect(plainText(out) == "llo")
    }

    @Test func reindexAfterEdit() throws {
        let out = try deck().applying([
            .init(insertText: InsertTextRequest(objectId: "el-1", text: "XY", insertionIndex: 5)),
        ])
        let el = out.slides?.first?.pageElements?.first?.shape?.text?.textElements?.first
        #expect(el?.startIndex == 0 && el?.endIndex == 7)  // "HelloXY"
    }

    @Test func updateTextStyleAppliesFieldMask() throws {
        let out = try deck().applying([
            .updateTextStyle(UpdateTextStyleRequest(
                objectId: "el-1",
                style: TextStyle(bold: true),
                textRange: Range(type: .all),
                fields: "bold")),
        ])
        #expect(firstShapeRuns(out).first?.style?.bold == true)
    }

    @Test func fieldMaskResetsUnlistedAbsentField() throws {
        // base has bold:true; patch is empty but fields names "bold" → reset (removed).
        var p = deck()
        p.slides?[0].pageElements?[0].shape?.text?.textElements?[0].textRun?.style = TextStyle(bold: true)
        let out = try p.applying([
            .updateTextStyle(UpdateTextStyleRequest(objectId: "el-1", style: TextStyle(), textRange: Range(type: .all), fields: "bold")),
        ])
        #expect(firstShapeRuns(out).first?.style?.bold == nil)
    }

    // MARK: unsupported

    @Test func unsupportedRequestThrowsWithLabel() {
        #expect(throws: GSlidesEditError.unsupportedRequest("rerouteLine")) {
            _ = try deck().applying([.rerouteLine(RerouteLineRequest(objectId: "el-1"))])
        }
    }
}

@Suite struct SemanticEditTests {
    func deck() -> Presentation {
        let shape = Shape(shapeType: .textBox, text: TextContent(textElements: [
            TextElement(startIndex: 0, endIndex: 5, paragraphMarker: ParagraphMarker(), textRun: TextRun(content: "Hello")),
        ]))
        let el = PageElement(
            objectId: "el-1",
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 100, translateY: 200, unit: .emu),
            shape: shape)
        return Presentation(slides: [Page(objectId: "s1", pageType: .slide, pageElements: [el])])
    }
    func el(_ p: Presentation) -> PageElement? { p.slides?.first?.pageElements?.first }

    @Test func moveExpandsToRelativeTransform() throws {
        let out = try deck().applying(SemanticEditBatch(edits: [
            SemanticEdit(op: .move, id: "el-1", dxEmu: 50, dyEmu: -30),
        ]))
        #expect(el(out)?.transform?.translateX == 150 && el(out)?.transform?.translateY == 170)
    }

    @Test func setTextReplacesWholeText() throws {
        let out = try deck().applying(SemanticEditBatch(edits: [
            SemanticEdit(op: .setText, id: "el-1", text: "World"),
        ]))
        let text = el(out)?.shape?.text?.textElements?.compactMap(\.textRun).map { $0.content ?? "" }.joined()
        #expect(text == "World")
    }

    @Test func restyleBuildsFieldMask() throws {
        let reqs = EditExpander.requests(for: SemanticEdit(op: .restyle, id: "el-1", bold: true, colorHex: "#FF0000", fontSizePt: 24))
        guard case .updateTextStyle(let r) = reqs.first?.kind else { Issue.record("not updateTextStyle"); return }
        #expect(r.fields == "bold,foregroundColor,fontSize")
        #expect(r.style?.bold == true)
        #expect(r.style?.fontSize?.magnitude == 24)
        #expect(r.style?.foregroundColor?.opaqueColor?.rgbColor?.red == 1)
    }

    @Test func restyleAppliesEndToEnd() throws {
        let out = try deck().applying(SemanticEditBatch(edits: [
            SemanticEdit(op: .restyle, id: "el-1", bold: true),
        ]))
        #expect(el(out)?.shape?.text?.textElements?.first?.textRun?.style?.bold == true)
    }

    @Test func deleteAndDuplicateAndOrder() throws {
        var p = deck()
        p.slides?[0].pageElements?.append(PageElement(objectId: "el-2", shape: Shape(shapeType: .rectangle)))
        let dup = try p.applying(SemanticEditBatch(edits: [SemanticEdit(op: .duplicate, id: "el-1", newId: "el-1b")]))
        #expect(dup.slides?.first?.pageElements?.contains { $0.objectId == "el-1b" } == true)
        let ordered = try p.applying(SemanticEditBatch(edits: [SemanticEdit(op: .order, id: "el-2", order: .back)]))
        #expect(ordered.slides?.first?.pageElements?.first?.objectId == "el-2")
        let deleted = try p.applying(SemanticEditBatch(edits: [SemanticEdit(op: .delete, id: "el-1")]))
        #expect(deleted.slides?.first?.pageElements?.contains { $0.objectId == "el-1" } == false)
    }

    @Test func contractValidatesAndAppliesFromJSON() throws {
        let json = #"{"edits":[{"op":"move","id":"el-1","dxEmu":10,"dyEmu":0},{"op":"setText","id":"el-1","text":"Hi"}]}"#
        let out = try GSlidesEditContract.apply(Data(json.utf8), to: deck())
        #expect(el(out)?.transform?.translateX == 110)
        let text = el(out)?.shape?.text?.textElements?.compactMap(\.textRun).map { $0.content ?? "" }.joined()
        #expect(text == "Hi")
    }

    @Test func emptyBatchRejected() {
        #expect(throws: GSlidesEditContractError.emptyBatch) {
            _ = try GSlidesEditContract.validate(Data(#"{"edits":[]}"#.utf8))
        }
    }

    @Test func schemaIsCompact() throws {
        // Guard the token-economy property: the edit schema stays small (≪ the 44-request wire schema).
        let bytes = try GSlidesEditContract.jsonSchemaData().count
        #expect(bytes < 2048)
    }
}
