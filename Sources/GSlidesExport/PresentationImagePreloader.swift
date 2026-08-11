import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import ImageIO

/// Loads every image a presentation references into a `GSlidesImageProvider` up front.
///
/// Export renderers draw synchronously, so without this an `AsyncImage` snapshots blank. `file://`
/// URLs load directly; `http(s)` URLs are fetched concurrently.
public enum PresentationImagePreloader {
    /// A provider holding every image that loaded, keyed by absolute URL string.
    ///
    /// A URL that fails to fetch or decode is dropped silently and the element renders as a
    /// placeholder, so the returned provider may cover fewer images than the deck references. There
    /// is no timeout and no concurrency limit: a deck referencing many slow URLs waits for all of
    /// them.
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

    /// The deduplicated image URLs across every slide, in first-seen order.
    ///
    /// Covers image and Sheets-chart elements, recursing into groups. Video thumbnails and page
    /// background pictures are not collected, so those still fetch asynchronously at render time.
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
