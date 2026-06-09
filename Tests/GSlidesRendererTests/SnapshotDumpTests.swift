import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import GSlidesSchema
import GSlidesPrompt
import UniformTypeIdentifiers
@testable import GSlidesRenderer

/// Dev tool: set GSLIDES_SNAPSHOT_DIR to dump rendered slides as PNGs for visual review.
@MainActor
@Suite struct SnapshotDumpTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dumpSemanticPresentation() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
        {"title": "Render Demo", "slides": [
            {"layout": "TITLE", "title": "swift-google-slides-view", "subtitle": "Google Slides API スキーマ準拠 JSON を SwiftUI で描画"},
            {"layout": "BIG_NUMBER", "title": "136", "big": true, "bodies": [{"text": "schemas in the discovery document"}]},
            {"title": "設計原則", "bodies": [{"bullets": ["語彙を発明しない（enum parity ⊆ discovery）", "依存の向きは内→外", "CLI で TDD"]}]},
            {"layout": "TITLE_AND_TWO_COLUMNS", "title": "Before / After", "bodies": [{"bullets": ["手書き UI", "実装ごとに発散"]}, {"bullets": ["スキーマ駆動", "プロファイル準拠"]}]}
        ]}
        """
        let presentation = try GSlidesGenerationContract.presentation(from: Data(json.utf8))
        for (index, slide) in (presentation.slides ?? []).enumerated() {
            let view = GSlidesSlideView(slide: slide, presentation: presentation).frame(width: 960)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: 960, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let url = directory.appendingPathComponent("slide-\(index + 1).png")
            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }
}
