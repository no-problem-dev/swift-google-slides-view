import CoreGraphics
import SwiftUI

/// レンダラー用の同期解決済み画像。絶対 URL 文字列をキーとする。
///
/// `AsyncImage` はメインランループの外でロードするため、PDF/PNG エクスポートで使う
/// `ImageRenderer` のスナップショットが画像到着前にスライドをキャプチャしてしまう。
/// プロバイダーを注入することでレンダラーが同期的な `Image` を描画できる。
/// エクスポートパスは全画像をこのプロバイダーにプリロードする。
/// 画面上のレンダリングでは nil のままにして `AsyncImage` を使い続ける。
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
    /// セットされている場合、レンダラーはこのプロバイダーから同期的に画像を描画する（エクスポートパス）。
    var gslidesImageProvider: GSlidesImageProvider? {
        get { self[GSlidesImageProviderKey.self] }
        set { self[GSlidesImageProviderKey.self] = newValue }
    }
}

private struct GSlidesSlideNumberKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

public extension EnvironmentValues {
    /// 現在のスライドの 1 始まりの番号。API がコンテンツを空のままにする `autoText` の
    /// SLIDE_NUMBER フィールドをプレゼンテーション時に解決するために使用する。
    var gslidesSlideNumber: Int? {
        get { self[GSlidesSlideNumberKey.self] }
        set { self[GSlidesSlideNumberKey.self] = newValue }
    }
}
