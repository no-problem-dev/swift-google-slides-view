import CoreGraphics
import SwiftUI

/// Synchronously-resolved images for the renderer, keyed by absolute URL string.
///
/// `AsyncImage` loads off the main run loop, so an `ImageRenderer` snapshot (used for PDF/PNG
/// export) captures the slide before images arrive. Injecting a provider lets the renderer draw a
/// synchronous `Image` instead — the export path preloads every image into one of these. On-screen
/// rendering leaves it nil and keeps using `AsyncImage`.
// CGImage is immutable and thread-safe in practice; the dictionary is built once before use.
public struct GSlidesImageProvider: @unchecked Sendable {
    public let images: [String: CGImage]

    public init(images: [String: CGImage]) {
        self.images = images
    }

    public func image(for url: URL) -> Image? {
        images[url.absoluteString].map { Image(decorative: $0, scale: 1, orientation: .up) }
    }
}

private struct GSlidesImageProviderKey: EnvironmentKey {
    static let defaultValue: GSlidesImageProvider? = nil
}

public extension EnvironmentValues {
    /// When set, the renderer draws images synchronously from this provider (export path).
    var gslidesImageProvider: GSlidesImageProvider? {
        get { self[GSlidesImageProviderKey.self] }
        set { self[GSlidesImageProviderKey.self] = newValue }
    }
}
