import A2ACore
import Foundation
import Testing
import GSlidesSchema
import GSlidesRequests
import GSlidesAssembly
@testable import GSlidesA2A

@Suite struct GSlidesA2ATests {
    func slide(_ id: String) -> Page {
        Page(
            objectId: id,
            pageType: .slide,
            pageElements: [
                PageElement(
                    objectId: "\(id)-title",
                    shape: Shape(
                        text: TextContent(textElements: [TextElement(textRun: TextRun(content: "Hello"))]),
                        placeholder: Placeholder(type: .title)
                    )
                )
            ]
        )
    }

    func wireRoundTrip(_ event: TaskArtifactUpdateEvent) throws -> TaskArtifactUpdateEvent {
        let data = try JSONEncoder().encode(event)
        return try JSONDecoder().decode(TaskArtifactUpdateEvent.self, from: data)
    }

    @Test func streamedDeckAssemblesAcrossWireRoundTrip() throws {
        let envelope = try GSlidesArtifactCoding.envelopeEvent(
            taskId: "task-1", contextId: "ctx-1", artifactId: "deck-1",
            presentation: Presentation(title: "My Deck", slides: [])
        )
        let slide1 = try GSlidesArtifactCoding.slideEvent(
            taskId: "task-1", contextId: "ctx-1", artifactId: "deck-1", page: slide("s1")
        )
        let slide2 = try GSlidesArtifactCoding.slideEvent(
            taskId: "task-1", contextId: "ctx-1", artifactId: "deck-1", page: slide("s2"), lastChunk: true
        )

        var assembler = GSlidesArtifactAssembler()
        for event in [envelope, slide1, slide2] {
            #expect(try assembler.apply(wireRoundTrip(event)))
        }
        #expect(assembler.isComplete)
        #expect(assembler.presentation?.title == "My Deck")
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["s1", "s2"])
        let text = assembler.presentation?.slides?.first?.pageElements?.first?
            .shape?.text?.textElements?.first?.textRun?.content
        #expect(text == "Hello")
    }

    @Test func batchUpdateDiffEventAppliesOverWire() throws {
        // Envelope a deck with one text element, then stream an element-level edit as a diff event.
        let envelope = try GSlidesArtifactCoding.envelopeEvent(
            taskId: "task-1", contextId: "ctx-1", artifactId: "deck-1",
            presentation: Presentation(title: "Deck", slides: [slide("s1")])
        )
        let diff = try GSlidesArtifactCoding.batchUpdateEvent(
            taskId: "task-1", contextId: "ctx-1", artifactId: "deck-1",
            requests: [.replaceAllText(ReplaceAllTextRequest(
                replaceText: "Bonjour", containsText: SubstringMatchCriteria(text: "Hello")))],
            lastChunk: true
        )
        var assembler = GSlidesArtifactAssembler()
        for event in [envelope, diff] {
            #expect(try assembler.apply(wireRoundTrip(event)))
        }
        #expect(assembler.isComplete)
        let text = assembler.presentation?.slides?.first?.pageElements?.first?
            .shape?.text?.textElements?.first?.textRun?.content
        #expect(text == "Bonjour")
    }

    @Test func foreignArtifactsAreIgnored() throws {
        let foreign = TaskArtifactUpdateEvent(
            taskId: "task-1", contextId: "ctx-1",
            artifact: Artifact(artifactId: "other", parts: [.text("hi")])
        )
        var assembler = GSlidesArtifactAssembler()
        #expect(try assembler.apply(foreign) == false)
        #expect(assembler.presentation == nil)
        #expect(try GSlidesArtifactCoding.chunks(from: foreign).isEmpty)
    }

    @Test func secondGSlidesArtifactIsNotMixedIn() throws {
        var assembler = GSlidesArtifactAssembler()
        let first = try GSlidesArtifactCoding.envelopeEvent(
            taskId: "t", contextId: "c", artifactId: "deck-1",
            presentation: Presentation(slides: [slide("s1")])
        )
        let other = try GSlidesArtifactCoding.slideEvent(
            taskId: "t", contextId: "c", artifactId: "deck-2", page: slide("intruder")
        )
        #expect(try assembler.apply(first))
        #expect(try assembler.apply(other) == false)
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["s1"])
    }

    @Test func metadataVocabularyIsDeclaredOnTheWire() throws {
        let event = try GSlidesArtifactCoding.envelopeEvent(
            taskId: "t", contextId: "c", artifactId: "deck-1", presentation: Presentation()
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any]
        let artifact = json?["artifact"] as? [String: Any]
        let metadata = artifact?["metadata"] as? [String: Any]
        #expect(metadata?[GSlidesA2AVocabulary.schemaKey] as? String == GSlidesA2AVocabulary.schemaURI)
    }

    @Test func completeArtifactDecodesDirectly() throws {
        let artifact = try GSlidesArtifactCoding.artifact(
            id: "deck-1",
            kind: .envelope,
            payload: Presentation(title: "One Shot", slides: [slide("s1")])
        )
        let presentation = try GSlidesArtifactCoding.presentation(from: artifact)
        #expect(presentation.title == "One Shot")
        #expect(presentation.slides?.count == 1)
    }

    @Test func nonGSlidesArtifactThrowsOnDirectDecode() {
        let artifact = Artifact(artifactId: "x", parts: [.text("nope")])
        #expect(throws: GSlidesA2AError.notAGSlidesArtifact) {
            _ = try GSlidesArtifactCoding.presentation(from: artifact)
        }
    }
}
