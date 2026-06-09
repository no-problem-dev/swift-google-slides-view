import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Exports a `Presentation` to raster images (PNG) — each slide individually, or all stacked into
/// one tall image for social posts. Like the PDF path, pass a preloaded `imageProvider`.
@MainActor
public enum PresentationImageRenderer {
    /// Default per-slide pixel size (1920×1080, i.e. the 16:9 page at scale 2 of 960×540).
    public static let defaultPixelSize = CGSize(width: 1920, height: 1080)

    /// One CGImage per slide.
    public static func slideImages(
        _ presentation: Presentation,
        pixelSize: CGSize = defaultPixelSize,
        imageProvider: GSlidesImageProvider? = nil
    ) -> [CGImage] {
        let pointSize = CGSize(width: pixelSize.width / 2, height: pixelSize.height / 2)
        return (presentation.slides ?? []).compactMap { slide in
            let view = GSlidesSlideView(slide: slide, presentation: presentation)
                .frame(width: pointSize.width, height: pointSize.height)
                .environment(\.gslidesImageProvider, imageProvider)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(pointSize)
            renderer.scale = 2
            return renderer.cgImage
        }
    }

    public static func pngData(
        _ presentation: Presentation,
        pixelSize: CGSize = defaultPixelSize,
        imageProvider: GSlidesImageProvider? = nil
    ) -> [Data] {
        slideImages(presentation, pixelSize: pixelSize, imageProvider: imageProvider).compactMap(Self.png)
    }

    /// All slides stacked vertically into one PNG (SNS-friendly single image).
    public static func stackedPNG(
        _ presentation: Presentation,
        pixelSize: CGSize = defaultPixelSize,
        spacing: Int = 0,
        imageProvider: GSlidesImageProvider? = nil
    ) -> Data? {
        let images = slideImages(presentation, pixelSize: pixelSize, imageProvider: imageProvider)
        guard !images.isEmpty else { return nil }
        let w = Int(pixelSize.width)
        let h = Int(pixelSize.height)
        let totalH = images.count * h + (images.count - 1) * spacing
        guard let ctx = CGContext(
            data: nil, width: w, height: totalH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: totalH))
        for (i, image) in images.enumerated() {
            // CGContext origin is bottom-left; stack top-to-bottom.
            let y = totalH - (i + 1) * h - i * spacing
            ctx.draw(image, in: CGRect(x: 0, y: y, width: w, height: h))
        }
        return ctx.makeImage().flatMap(Self.png)
    }

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
