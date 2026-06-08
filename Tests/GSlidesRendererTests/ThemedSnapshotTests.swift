import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import GSlidesSchema
import UniformTypeIdentifiers
@testable import GSlidesRenderer

@MainActor
@Suite struct ThemedSnapshotTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"] != nil))
    func dumpThemedDeck() throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GSLIDES_SNAPSHOT_DIR"]!)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // A deck with a dark, branded master color scheme.
        let scheme = ColorScheme(colors: [
            ThemeColorPair(type: .background1, color: RgbColor(red: 0.09, green: 0.11, blue: 0.18)),
            ThemeColorPair(type: .text1, color: RgbColor(red: 0.93, green: 0.95, blue: 0.98)),
            ThemeColorPair(type: .accent1, color: RgbColor(red: 0.40, green: 0.78, blue: 0.94)),
            ThemeColorPair(type: .accent2, color: RgbColor(red: 0.98, green: 0.55, blue: 0.38)),
        ])
        let master = Page(objectId: "master-1", pageType: .master,
                          pageProperties: PageProperties(colorScheme: scheme))

        func slide(_ id: String, title: String, big: Bool, bullets: [String], accent: ThemeColorType) -> Page {
            var els: [PageElement] = [
                PageElement(objectId: "\(id)-t", shape: Shape(
                    text: TextContent(textElements: [TextElement(textRun: TextRun(content: title + "\n",
                        style: TextStyle(foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: accent)))))]),
                    placeholder: Placeholder(type: big ? .centeredTitle : .title)))
            ]
            if !bullets.isEmpty {
                els.append(PageElement(objectId: "\(id)-b", shape: Shape(
                    text: TextContent(textElements: bullets.map { TextElement(
                        paragraphMarker: ParagraphMarker(bullet: Bullet(glyph: "●")),
                        textRun: TextRun(content: $0 + "\n")) }),
                    placeholder: Placeholder(type: .body, index: 0))))
            }
            return Page(objectId: id, pageType: .slide, pageElements: els,
                        slideProperties: SlideProperties(masterObjectId: "master-1"))
        }

        let deck = Presentation(title: "Themed", slides: [
            slide("s1", title: "Branded Dark Theme", big: true, bullets: [], accent: .accent1),
            slide("s2", title: "Accent colors resolve", big: false,
                  bullets: ["BACKGROUND1 → canvas", "TEXT1 → body", "ACCENT1/2 → headings"], accent: .accent2),
        ], masters: [master])

        for (i, s) in (deck.slides ?? []).enumerated() {
            let renderer = ImageRenderer(content: GSlidesSlideView(slide: s, presentation: deck).frame(width: 960))
            renderer.proposedSize = ProposedViewSize(width: 960, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let url = dir.appendingPathComponent("themed-\(i + 1).png")
            let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
    }
}
