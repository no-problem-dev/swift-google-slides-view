import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// `Presentation` をラスター画像（PNG）にエクスポートする — スライド個別、またはソーシャル投稿用に全スライドを縦に積んだ 1 枚。
/// PDF パスと同様、プリロード済みの `imageProvider` を渡す。
@MainActor
public enum PresentationImageRenderer {
    /// スライドごとのデフォルトピクセルサイズ（1920×1080、つまり 960×540 の 16:9 ページをスケール 2 で出力）。
    public static let defaultPixelSize = CGSize(width: 1920, height: 1080)

    /// スライドごとに 1 つの CGImage を返す。
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

    /// 全スライドを縦に積んだ 1 枚の PNG（SNS 投稿に適した単一画像）。
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
