import Foundation
import Testing
import GSlidesSchema
@testable import GSlidesAssembly

@Suite struct GSlidesAssemblyTests {
    func envelope(slides: [Page] = []) throws -> GSlidesChunk {
        let presentation = Presentation(title: "Deck", pageSize: nil, slides: slides)
        return GSlidesChunk(payload: try JSONEncoder().encode(presentation))
    }

    func slideChunk(_ id: String, lastChunk: Bool = false) throws -> GSlidesChunk {
        let page = Page(objectId: id, pageType: .slide)
        return GSlidesChunk(payload: try JSONEncoder().encode(page), append: true, lastChunk: lastChunk)
    }

    @Test func envelopeThenAppendsThenComplete() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(envelope())
        try assembler.apply(slideChunk("s1"))
        try assembler.apply(slideChunk("s2"))
        try assembler.apply(slideChunk("s3", lastChunk: true))
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["s1", "s2", "s3"])
        #expect(assembler.presentation?.title == "Deck")
        #expect(assembler.isComplete)
    }

    @Test func nonAppendReplacesEntireState() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(envelope(slides: [Page(objectId: "old")]))
        try assembler.apply(envelope(slides: [Page(objectId: "new")]))
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["new"])
    }

    @Test func appendBeforeEnvelopeCreatesImplicitPresentation() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(slideChunk("s1"))
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["s1"])
        #expect(assembler.presentation?.title == nil)
    }

    @Test func invalidPayloadThrowsAndPreservesState() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(envelope(slides: [Page(objectId: "keep")]))
        let before = assembler
        let bad = GSlidesChunk(payload: Data("not json".utf8), append: true)
        #expect(throws: GSlidesAssemblyError.self) {
            try assembler.apply(bad)
        }
        #expect(assembler == before)
    }

    @Test func chunkAfterCompletionThrows() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(slideChunk("s1", lastChunk: true))
        #expect(throws: GSlidesAssemblyError.chunkAfterCompletion) {
            try assembler.apply(slideChunk("s2"))
        }
    }

    @Test func envelopeWithInitialSlidesAccumulates() throws {
        var assembler = GSlidesAssembler()
        try assembler.apply(envelope(slides: [Page(objectId: "s0")]))
        try assembler.apply(slideChunk("s1"))
        #expect(assembler.presentation?.slides?.map(\.objectId) == ["s0", "s1"])
    }

    @Test func assembleConvenience() throws {
        let presentation = try GSlidesAssembler.assemble([
            envelope(),
            slideChunk("s1"),
            slideChunk("s2", lastChunk: true),
        ])
        #expect(presentation.slides?.count == 2)
    }

    @Test func emptySequenceThrows() {
        #expect(throws: GSlidesAssemblyError.self) {
            _ = try GSlidesAssembler.assemble([])
        }
    }
}
