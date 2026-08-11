import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import SwiftUI

/// Exports a presentation as a PDF, one slide per page, by drawing each slide view into a PDF
/// `CGContext` through `ImageRenderer`.
///
/// No UIKit, so it runs under a command-line test as well as in an app.
///
/// Pass a preloaded `imageProvider` from `PresentationImagePreloader` if the deck contains images:
/// rendering is synchronous, so an `AsyncImage` snapshots blank.
@MainActor
public enum PresentationPDFRenderer {
    /// The default page size for a 16:9 deck, in PostScript points — 960 × 540, or 10 in × 5.625 in
    /// at 96 dpi.
    public static let defaultPageSize = CGSize(width: 960, height: 540)

    /// The presentation rendered as PDF bytes, one page per slide.
    ///
    /// Returns empty data if the PDF context cannot be created, and produces a zero-page PDF for a
    /// deck with no slides — neither case throws, so check the result before writing it.
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

    /// Writes the PDF to a temporary file and returns its URL, ready for `ShareLink` or
    /// `fileExporter`.
    ///
    /// The name is sanitized — trimmed, capped at 60 characters, with `/` and `:` replaced — and
    /// defaults to the presentation title. Two decks with the same title overwrite each other, and
    /// nothing cleans the file up; that is the caller's job.
    ///
    /// - Throws: The file-writing error if the temporary directory cannot be written to.
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

private enum PresentationExportNaming {
    static func fileName(_ raw: String, ext: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "presentation" : String(trimmed.prefix(60))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safe).\(ext)"
    }
}
