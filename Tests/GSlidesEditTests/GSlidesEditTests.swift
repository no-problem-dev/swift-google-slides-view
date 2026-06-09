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

@Suite struct GSlidesEditContractTests {
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
    func text(_ p: Presentation) -> String? {
        el(p)?.shape?.text?.textElements?.compactMap(\.textRun).map { $0.content ?? "" }.joined()
    }

    // The agent emits OFFICIAL batchUpdate request JSON — no invented vocabulary.
    @Test func appliesOfficialBatchUpdateJSON() throws {
        let json = """
        {"requests":[
          {"updatePageElementTransform":{"objectId":"el-1","applyMode":"RELATIVE","transform":{"scaleX":1,"scaleY":1,"translateX":50,"translateY":-30,"unit":"EMU"}}},
          {"replaceAllText":{"containsText":{"text":"Hello"},"replaceText":"World"}}
        ]}
        """
        let out = try GSlidesEditContract.apply(Data(json.utf8), to: deck())
        #expect(el(out)?.transform?.translateX == 150 && el(out)?.transform?.translateY == 170)
        #expect(text(out) == "World")
    }

    // Omitting `fields` updates exactly the attributes provided (inferred mask) — not a wipe.
    @Test func updateTextStyleWithoutFieldsInfersMask() throws {
        var p = deck()
        p.slides?[0].pageElements?[0].shape?.text?.textElements?[0].textRun?.style =
            TextStyle(fontSize: Dimension(magnitude: 18, unit: .pt))
        let json = #"{"requests":[{"updateTextStyle":{"objectId":"el-1","style":{"bold":true},"textRange":{"type":"ALL"}}}]}"#
        let out = try GSlidesEditContract.apply(Data(json.utf8), to: p)
        let style = el(out)?.shape?.text?.textElements?.first?.textRun?.style
        #expect(style?.bold == true)                 // applied
        #expect(style?.fontSize?.magnitude == 18)    // preserved (not wiped)
    }

    @Test func validateAcceptsBareArray() throws {
        let json = #"[{"deleteObject":{"objectId":"el-1"}}]"#
        let requests = try GSlidesEditContract.validate(Data(json.utf8))
        #expect(requests.count == 1)
        guard case .deleteObject = requests.first?.kind else { Issue.record("not deleteObject"); return }
    }

    @Test func emptyBatchRejected() {
        #expect(throws: GSlidesEditContractError.emptyBatch) {
            _ = try GSlidesEditContract.validate(Data(#"{"requests":[]}"#.utf8))
        }
    }

    // One bad edit (stale objectId) must not drop the rest (best-effort).
    @Test func lenientSkipsBadEdit() throws {
        let json = """
        {"requests":[
          {"deleteObject":{"objectId":"does-not-exist"}},
          {"replaceAllText":{"containsText":{"text":"Hello"},"replaceText":"Survived"}}
        ]}
        """
        let out = try GSlidesEditContract.apply(Data(json.utf8), to: deck())
        #expect(text(out) == "Survived")
    }

    @Test func promptBlockListsCuratedOpsAndExamples() {
        let block = GSlidesEditContract.promptBlock()
        #expect(block.contains("updatePageElementTransform"))
        #expect(block.contains("EDIT EXAMPLES"))
        #expect(GSlidesEditContract.curatedOperations.count == 9)
    }

    // Disabling an operation removes it from the offered set, the prompt, and validation.
    @Test func allowingNarrowsOperations() throws {
        let allowed: Set<String> = ["updateTextStyle", "replaceAllText"]  // delete NOT allowed
        let block = GSlidesEditContract.promptBlock(allowing: allowed)
        #expect(block.contains("updateTextStyle"))
        #expect(!block.contains("deleteObject"))

        // A deleteObject request is dropped (not offered); the allowed edit still applies.
        let json = """
        {"requests":[
          {"deleteObject":{"objectId":"el-1"}},
          {"replaceAllText":{"containsText":{"text":"Hello"},"replaceText":"Kept"}}
        ]}
        """
        let requests = try GSlidesEditContract.validate(Data(json.utf8), allowing: allowed)
        #expect(requests.count == 1)
        let out = try GSlidesEditContract.apply(Data(json.utf8), to: deck(), allowing: allowed)
        #expect(text(out) == "Kept")
        #expect(el(out) != nil)  // el-1 NOT deleted (op was disabled)
    }

    @Test func operationNameReadsTheSetMember() {
        let r = Request.deleteObject(DeleteObjectRequest(objectId: "x"))
        #expect(GSlidesEditContract.operationName(of: r) == "deleteObject")
    }
}

@Suite struct DeckInspectorTests {
    func deck() -> Presentation {
        let title = PageElement(
            objectId: "s1-title",
            size: Size(width: Dimension(magnitude: 100, unit: .pt), height: Dimension(magnitude: 50, unit: .pt)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 914400, translateY: 100000, unit: .emu),
            shape: Shape(text: TextContent(textElements: [TextElement(textRun: TextRun(content: "  Hello World  "))]),
                         placeholder: Placeholder(type: .title)))
        let img = PageElement(objectId: "s1-img", image: Image(sourceUrl: "media://x"))
        let slide = Page(objectId: "s1", pageType: .slide, pageElements: [title, img])
        return Presentation(title: "My Deck", slides: [slide])
    }

    @Test func snapshotExposesObjectIdsKindsAndText() {
        let snap = GSlidesDeckInspector.snapshot(deck())
        #expect(snap.deckTitle == "My Deck")
        #expect(snap.slideCount == 1 && snap.slideIds == ["s1"])
        #expect(snap.elements.map(\.objectId) == ["s1-title", "s1-img"])
        let title = snap.elements[0]
        #expect(title.kind == "text" && title.label == "TITLE")
        #expect(title.text == "Hello World")              // trimmed
        #expect(title.xEmu == 914400 && title.yEmu == 100000)
        #expect(title.widthEmu == 1_270_000)              // 100pt → EMU
        #expect(snap.elements[1].kind == "image" && snap.elements[1].label == "PICTURE")
    }

    @Test func snapshotJSONIsStableAndReadable() throws {
        let json = String(decoding: try GSlidesDeckInspector.snapshotJSON(deck()), as: UTF8.self)
        #expect(json.contains("\"objectId\":\"s1-title\""))
        #expect(json.contains("\"label\":\"TITLE\""))
    }

    @Test func roundTripsThroughEditByObjectId() throws {
        // The inspector's objectId is exactly what an official edit request targets.
        let snap = GSlidesDeckInspector.snapshot(deck())
        let id = snap.elements[0].objectId
        let out = try deck().applying([.deleteObject(DeleteObjectRequest(objectId: id))])
        #expect(out.slides?.first?.pageElements?.contains { $0.objectId == id } == false)
    }
}
