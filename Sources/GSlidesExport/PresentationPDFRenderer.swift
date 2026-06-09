import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import SwiftUI

/// Exports a `Presentation` to PDF — one slide per page — using `ImageRenderer` to draw each
/// `GSlidesSlideView` into a PDF-page `CGContext`. Pure (no UIKit), so it runs on the CLI for tests.
///
/// Pass an `imageProvider` (preloaded images) so pictures appear; `AsyncImage` would otherwise
/// snapshot blank. Build one with `PresentationImagePreloader`.
@MainActor
public enum PresentationPDFRenderer {
    /// Default page size in PostScript points for a 16:9 presentation (10in × 5.625in at 96dpi-ish scale).
    public static let defaultPageSize = CGSize(width: 960, height: 540)

    public static func pdfData(
        _ presentation: Presentation,
        pageSize: CGSize = defaultPageSize,
        imageProvider: GSlidesImageProvider? = nil
    ) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(origin: .zero, size: pageSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }

        for slide in presentation.slides ?? [] {
            let view = GSlidesSlideView(slide: slide, presentation: presentation)
                .frame(width: pageSize.width, height: pageSize.height)
                .environment(\.gslidesImageProvider, imageProvider)
            let renderer = ImageRenderer(content: view)
            renderer.render { _, render in
                ctx.beginPDFPage(nil)
                render(ctx)
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
        return data as Data
    }

    /// Writes the PDF to a temporary file and returns its URL (for `ShareLink` / `fileExporter`).
    /// `filename` is sanitized; defaults to the presentation title.
    public static func pdfFile(
        _ presentation: Presentation,
        filename: String? = nil,
        pageSize: CGSize = defaultPageSize,
        imageProvider: GSlidesImageProvider? = nil
    ) throws -> URL {
        let data = pdfData(presentation, pageSize: pageSize, imageProvider: imageProvider)
        let name = PresentationExportNaming.fileName(filename ?? presentation.title ?? "presentation", ext: "pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum PresentationExportNaming {
    static func fileName(_ raw: String, ext: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "presentation" : String(trimmed.prefix(60))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safe).\(ext)"
    }
}
