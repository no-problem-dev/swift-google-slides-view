import CoreGraphics
import ImageIO
import Foundation
import Testing
import GSlidesSchema
import GSlidesPrompt
import GSlidesRenderer
@testable import GSlidesExport

@MainActor
@Suite struct GSlidesExportTests {
    func presentation() throws -> Presentation {
        try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
    }

    @Test func pdfHasOnePagePerSlideAndIsValid() throws {
        let p = try presentation()
        let data = PresentationPDFRenderer.pdfData(p)
        #expect(data.count > 1000)
        // %PDF header + page count via CGPDFDocument
        let doc = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(doc.numberOfPages == p.slides?.count)
    }

    @Test func pdfFileWritesNamedTempFile() throws {
        let url = try PresentationPDFRenderer.pdfFile(try presentation(), filename: "My Presentation: 2026/Q2")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "pdf")
        #expect(!url.lastPathComponent.contains("/"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func perSlidePNGs() throws {
        let p = try presentation()
        let pngs = PresentationImageRenderer.pngData(p, pixelSize: CGSize(width: 640, height: 360))
        #expect(pngs.count == p.slides?.count)
        #expect(pngs.allSatisfy { $0.count > 100 })
    }

    @Test func stackedPNGIsTall() throws {
        let p = try presentation()
        let data = try #require(PresentationImageRenderer.stackedPNG(p, pixelSize: CGSize(width: 640, height: 360)))
        let img = try #require(CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        #expect(img.width == 640)
        #expect(img.height == 360 * (p.slides?.count ?? 0))
    }

    @Test func preloaderCollectsImageURLs() throws {
        let json = """
        {"title":"x","slides":[
          {"layout":"TITLE_AND_BODY","title":"a","bodies":[{"bullets":["b"],"imageUrl":"file:///tmp/a.png"}]},
          {"layout":"TITLE_AND_BODY","title":"c","bodies":[{"bullets":["d"],"imageUrl":"file:///tmp/b.png"}]}
        ]}
        """
        let p = try GSlidesGenerationContract.presentation(from: Data(json.utf8))
        let urls = PresentationImagePreloader.imageURLs(in: p).map(\.absoluteString)
        #expect(urls.contains("file:///tmp/a.png"))
        #expect(urls.contains("file:///tmp/b.png"))
    }
}
