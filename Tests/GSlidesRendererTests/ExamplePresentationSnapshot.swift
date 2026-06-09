import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import GSlidesSchema
import GSlidesPrompt
import UniformTypeIdentifiers
@testable import GSlidesRenderer

@MainActor
@Suite struct ExamplePresentationSnapshot {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dumpExample() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let presentation = try GSlidesGenerationContract.presentation(from: Data(GSlidesGenerationContract.examplePresentationJSON().utf8))
        for (i, s) in (presentation.slides ?? []).enumerated() {
            let r = ImageRenderer(content: GSlidesSlideView(slide: s, presentation: presentation).frame(width: 1024))
            r.proposedSize = ProposedViewSize(width: 1024, height: nil)
            r.scale = 2
            let image = try #require(r.cgImage)
            let url = dir.appendingPathComponent("ex-\(String(format: "%02d", i + 1)).png")
            let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
    }
}
