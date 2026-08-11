import CoreGraphics
import SwiftUI

/// Images already in memory, keyed by absolute URL string, for renderers that cannot wait.
///
/// `AsyncImage` loads off the main run loop, so an `ImageRenderer` snapshot — the PDF and PNG export
/// path — captures the slide before the image arrives. Injecting a provider lets the renderer draw a
/// synchronous `Image` instead. Export preloads every image into one of these.
///
/// Leave it nil for on-screen rendering, which keeps `AsyncImage` and its progressive loading.
/// A URL that is not in the dictionary falls back to `AsyncImage` rather than failing.
// CGImage is immutable and thread-safe in practice; the dictionary is built once before use.
public struct GSlidesImageProvider: @unchecked Sendable {
    public let images: [String: CGImage]

    public init(images: [String: CGImage]) {
        self.images = images
    }

    /// The preloaded image for a URL, or nil when it was never loaded.
    ///
    /// Decorative: the returned image carries no accessibility label, since a slide's alt text lives
    /// on the page element.
    public func image(for url: URL) -> Image? {
        images[url.absoluteString].map { Image(decorative: $0, scale: 1, orientation: .up) }
    }
}

private struct GSlidesImageProviderKey: EnvironmentKey {
    static let defaultValue: GSlidesImageProvider? = nil
}

public extension EnvironmentValues {
    /// When set, the renderer draws images synchronously from this provider — the export path.
    /// Leave nil on screen so images load progressively.
    var gslidesImageProvider: GSlidesImageProvider? {
        get { self[GSlidesImageProviderKey.self] }
        set { self[GSlidesImageProviderKey.self] = newValue }
    }
}

private struct GSlidesSlideNumberKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

public extension EnvironmentValues {
    /// The current slide's one-based number, used to resolve a SLIDE_NUMBER `autoText` field.
    ///
    /// The API leaves that field's content empty, so without this the slide number renders blank.
    /// `GSlidesSlideView` sets it from the slide's position in the deck.
    var gslidesSlideNumber: Int? {
        get { self[GSlidesSlideNumberKey.self] }
        set { self[GSlidesSlideNumberKey.self] = newValue }
    }
}
