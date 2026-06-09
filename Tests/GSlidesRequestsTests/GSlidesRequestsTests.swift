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

    @Test func everyDiscoveryRequestKindIsTyped() throws {
        // Parity: the typed Kind accessor must cover EVERY batchUpdate request the spec defines.
        // Decode `{"<kind>":{}}` for each discovery `Request` property and assert it maps to a
        // concrete case — never `.other`. This pins the write-side protocol == the discovery doc.
        let kinds = try Self.discoveryRequestKinds()
        #expect(kinds.count == 44, "discovery defines \(kinds.count) request kinds")
        for name in kinds {
            let r = try JSONDecoder().decode(Request.self, from: Data("{\"\(name)\":{}}".utf8))
            #expect(r.kind != .other, "Request.Kind has no case for \(name)")
        }
    }

    @Test func emptyRequestMapsToOther() {
        // `.other` now means exactly "no member set" (or a kind newer than this mirror).
        #expect(Request().kind == .other)
    }

    @Test func rerouteLineIsNowFirstClass() throws {
        let r = Request.rerouteLine(RerouteLineRequest(objectId: "line-1"))
        let back = try roundTrip(r)
        #expect(back.rerouteLine?.objectId == "line-1")
        guard case .rerouteLine(let line) = back.kind else { Issue.record("not rerouteLine"); return }
        #expect(line.objectId == "line-1")
    }

    static func discoveryRequestKinds() throws -> [String] {
        let data = try GSlidesSpec.discoveryDocument()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let schemas = json?["schemas"] as? [String: Any]
        let request = schemas?["Request"] as? [String: Any]
        let props = request?["properties"] as? [String: Any]
        return Array(props?.keys ?? [:].keys)
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
