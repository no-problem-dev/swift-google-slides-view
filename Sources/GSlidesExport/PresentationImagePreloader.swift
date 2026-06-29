import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import ImageIO

/// プレゼンテーションが参照する全画像を `GSlidesImageProvider` にプリロードする。エクスポートレンダラーが
/// 同期的に描画できるようにし（`AsyncImage` のブランクスナップショットを防ぐ）。file:// は即時ロード、http(s) は並行フェッチ。
public enum PresentationImagePreloader {
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

    /// 全スライドにわたる重複除去済みの画像 URL（シェイプは画像を持たない; image / sheetsChart 要素が持つ）。
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
