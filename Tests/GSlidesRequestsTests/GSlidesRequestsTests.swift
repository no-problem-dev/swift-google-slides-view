import Foundation
import Testing
import GSlidesSchema
@testable import GSlidesRequests

@Suite struct GSlidesRequestsTests {
    func roundTrip<T: Codable & Equatable>(_ v: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(v))
    }

    @Test func batchUpdateRoundTrips() throws {
        let batch = BatchUpdatePresentationRequest(requests: [
            .createSlide(CreateSlideRequest(objectId: "s1", insertionIndex: 0,
                slideLayoutReference: LayoutReference(predefinedLayout: .titleAndBody))),
            .insertText(InsertTextRequest(objectId: "shape-1", text: "Hello", insertionIndex: 0)),
            .replaceAllText(ReplaceAllTextRequest(replaceText: "X")),
        ])
        let back = try roundTrip(batch)
        #expect(back == batch)
        #expect(back.requests?.count == 3)
    }

    @Test func requestKindMapsFirstSetMember() {
        let r = Request.createShape(CreateShapeRequest(objectId: "o", shapeType: CreateShapeRequestShapeType(rawValue: "RECTANGLE")))
        guard case .createShape(let shape) = r.kind else { Issue.record("not createShape"); return }
        #expect(shape.objectId == "o")
    }

    @Test func unmodeledRequestStillRoundTrips() throws {
        // A request the typed Kind accessor doesn't enumerate (rerouteLine) still encodes/decodes.
        let r = Request(rerouteLine: RerouteLineRequest(objectId: "line-1"))
        let back = try roundTrip(r)
        #expect(back.rerouteLine?.objectId == "line-1")
        #expect(back.kind == .other)
    }

    @Test func wireShapeMatchesOfficialFieldNames() throws {
        let r = Request.insertText(InsertTextRequest(objectId: "x", text: "hi", insertionIndex: 2))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(r)) as? [String: Any]
        let insertText = json?["insertText"] as? [String: Any]
        #expect(insertText?["objectId"] as? String == "x")
        #expect(insertText?["insertionIndex"] as? Int == 2)
    }

    @Test func realBatchUpdateJSONDecodes() throws {
        // Shape mirrors the official batchUpdate request body.
        let json = """
        {"requests":[
          {"createSlide":{"objectId":"MyNewSlide","insertionIndex":1,
            "slideLayoutReference":{"predefinedLayout":"TITLE_AND_TWO_COLUMNS"}}},
          {"insertText":{"objectId":"MyTextBox","text":"Hello world","insertionIndex":0}},
          {"updateTextStyle":{"objectId":"MyTextBox","style":{"bold":true},
            "fields":"bold","textRange":{"type":"ALL"}}}
        ],"writeControl":{"requiredRevisionId":"abc"}}
        """
        let batch = try JSONDecoder().decode(BatchUpdatePresentationRequest.self, from: Data(json.utf8))
        #expect(batch.requests?.count == 3)
        #expect(batch.requests?[0].createSlide?.slideLayoutReference?.predefinedLayout == .titleAndTwoColumns)
        #expect(batch.requests?[2].updateTextStyle?.style?.bold == true)
        #expect(batch.writeControl?.requiredRevisionId == "abc")
    }
}
