import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import ImageIO

/// Preloads every image a deck references into a `GSlidesImageProvider`, so the export renderers
/// draw them synchronously (no blank `AsyncImage` snapshots). file:// loads immediately; http(s)
/// is fetched concurrently.
public enum DeckImagePreloader {
    public static func provider(for presentation: Presentation) async -> GSlidesImageProvider {
        let urls = imageURLs(in: presentation)
        var map: [String: CGImage] = [:]
        await withTaskGroup(of: (String, CGImage?).self) { group in
            for url in urls {
                group.addTask { (url.absoluteString, await loadCGImage(url)) }
            }
            for await (key, image) in group {
                if let image { map[key] = image }
            }
        }
        return GSlidesImageProvider(images: map)
    }

    /// Distinct image URLs across all slides (shapes carry no images; image / sheetsChart elements do).
    static func imageURLs(in presentation: Presentation) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        func collect(_ elements: [PageElement]?) {
            for element in elements ?? [] {
                let raw: String?
                switch element.kind {
                case .image(let image): raw = image.contentUrl ?? image.sourceUrl
                case .sheetsChart(let chart): raw = chart.contentUrl
                case .elementGroup(let group): collect(group.children); raw = nil
                default: raw = nil
                }
                if let raw, let url = URL(string: raw), seen.insert(url.absoluteString).inserted {
                    urls.append(url)
                }
            }
        }
        for slide in presentation.slides ?? [] { collect(slide.pageElements) }
        return urls
    }

    static func loadCGImage(_ url: URL) async -> CGImage? {
        if url.isFileURL {
            return CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
                CGImageSourceCreateImageAtIndex($0, 0, nil)
            }
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
