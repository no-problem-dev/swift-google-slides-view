import CoreGraphics
import Foundation
import GSlidesRenderer
import GSlidesSchema
import SwiftUI

/// `Presentation` を PDF にエクスポートする — スライド 1 枚が 1 ページ — `ImageRenderer` を使って
/// 各 `GSlidesSlideView` を PDF ページの `CGContext` に描画する。UIKit 不使用のため CLI のテストでも動作する。
///
/// 画像を表示するには、プリロード済みの `imageProvider` を渡す（未渡しの場合 `AsyncImage` がブランクでスナップショットされる）。
/// `PresentationImagePreloader` でビルドする。
@MainActor
public enum PresentationPDFRenderer {
    /// 16:9 プレゼンテーションのデフォルトページサイズ（PostScript ポイント。10in × 5.625in、約 96dpi スケール）。
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

    /// PDF を一時ファイルに書き込み、そのURLを返す（`ShareLink` / `fileExporter` 用）。
    /// `filename` はサニタイズされる。省略時はプレゼンテーションタイトルがデフォルト。
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
