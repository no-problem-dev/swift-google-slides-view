import DesignSystem
import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// 1 枚のスライドをプレゼンテーションのページサイズに合わせた固定アスペクトキャンバスに描画する。
/// ジオメトリ（size + transform、レイアウトから継承している場合も含む）を持つ要素は
/// ページ座標で絶対配置する。ジオメトリを持たないセマンティック層要素は
/// プレースホルダータイプ主導のスタックレイアウトにフォールバックする。
///
/// カラーはプレゼンテーションのテーマから取得する。master/layout/slide の `ColorScheme` を
/// DS `ColorPalette`（`PresentationColorPalette`）に射影し、スライドコンテンツと DS クロームの
/// 両方が `@Environment(\.colorPalette)` を共有する。
public struct GSlidesSlideView: View {
    public var slide: Page
    public var presentation: Presentation
    /// プレゼンテーションが定義していないスロット用のベース DS パレット。nil の場合、
    /// 周囲のアプリパレット（`@Environment(\.colorPalette)`、DS ThemeProvider など）を使用する。
    /// プレゼンテーション未定義のスロットとクロームはアプリのダークモードに従い、
    /// キャンバスに対しては自身のカラーが権威を保つ。
    public var basePalette: (any ColorPalette)?

    @Environment(\.colorPalette) private var envPalette
    @Environment(\.gslidesImageProvider) private var imageProvider

    public init(slide: Page, presentation: Presentation, basePalette: (any ColorPalette)? = nil) {
        self.slide = slide
        self.presentation = presentation
        self.basePalette = basePalette
    }

    private var presentationPalette: PresentationColorPalette {
        PresentationColorPalette(scheme: PresentationTheme.colorScheme(for: slide, in: presentation), base: basePalette ?? envPalette)
    }

    public var body: some View {
        let pageSize = PageGeometry.pageSize(of: presentation)
        let presentationPalette = presentationPalette
        let palette = GSlidesPalette(presentation: presentationPalette)
        GeometryReader { proxy in
            let emuScale = proxy.size.width / pageSize.width
            let pointScale = proxy.size.width / (pageSize.width / EMU.perPoint)
            let elements = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
            let positioned = elements.filter { PageGeometry.frame(of: $0) != nil }
            let flowing = elements.filter { PageGeometry.frame(of: $0) == nil }

            ZStack(alignment: .topLeading) {
                slideBackground(presentationPalette)
                ForEach(positioned, id: \.objectId) { element in
                    let frame = PageGeometry.frame(of: element)!
                    ElementView(element: element, pointScale: pointScale, palette: palette)
                        .frame(width: frame.width * emuScale, height: frame.height * emuScale)
                        .offset(x: frame.minX * emuScale, y: frame.minY * emuScale)
                }
                if !flowing.isEmpty {
                    SemanticSlideLayout(
                        elements: flowing,
                        layoutName: layoutName,
                        pointScale: pointScale,
                        palette: palette
                    )
                    .padding(proxy.size.width * 0.06)
                }
            }
        }
        .environment(\.gslidesSlideNumber, slideNumber)
        .aspectRatio(pageSize.width / pageSize.height, contentMode: .fit)
        .clipped()
        // Chrome that reads @Environment(\.colorPalette) (DS components) shares the presentation's theme.
        .environment(\.colorPalette, presentationPalette)
    }

    /// スライドの背景。ページが定義していればストレッチされたピクチャフィル、なければテーマカラーの単色塗り。
    @ViewBuilder
    private func slideBackground(_ presentationPalette: PresentationColorPalette) -> some View {
        if let url = PresentationTheme.backgroundFill(for: slide, in: presentation)?
            .stretchedPictureFill?.contentUrl.flatMap(URL.init(string:)) {
            if let provided = imageProvider?.image(for: url) {
                provided.resizable().scaledToFill()
            } else {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() }
                    else { PresentationTheme.backgroundColor(for: slide, in: presentation, palette: presentationPalette) }
                }
            }
        } else {
            PresentationTheme.backgroundColor(for: slide, in: presentation, palette: presentationPalette)
        }
    }

    /// プレゼンテーション内でのスライドの 1 始まりの位置（autoText SLIDE_NUMBER 用）。
    private var slideNumber: Int? {
        (presentation.slides ?? []).firstIndex { $0.objectId == slide.objectId }.map { $0 + 1 }
    }

    private var layoutName: PredefinedLayout? {
        guard let layoutPage = PlaceholderResolver.layoutPage(for: slide, in: presentation),
              let name = layoutPage.layoutProperties?.name
        else { return nil }
        return PredefinedLayout(rawValue: name)
    }
}

/// ジオメトリなし要素のレイアウト名認識配置。
/// タイトルバンドを上部に（TITLE / SECTION_HEADER 系は中央揃え）、
/// ボディを横並びに、画像は残りのスペースを埋める。
struct SemanticSlideLayout: View {
    var elements: [PageElement]
    var layoutName: PredefinedLayout?
    var pointScale: Double
    var palette: GSlidesPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * pointScale) {
            if centersVertically { Spacer() }
            ForEach(titles, id: \.objectId) { element in
                ElementView(element: element, pointScale: pointScale, palette: palette)
            }
            ForEach(subtitles, id: \.objectId) { element in
                ElementView(element: element, pointScale: pointScale, palette: palette)
            }
            if !contents.isEmpty {
                HStack(alignment: .top, spacing: 16 * pointScale) {
                    ForEach(contents, id: \.objectId) { element in
                        ElementView(element: element, pointScale: pointScale, palette: palette)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: centersHorizontally ? .center : .leading)
    }

    private var centersVertically: Bool {
        switch layoutName {
        case .some(.title), .some(.sectionHeader), .some(.mainPoint): true
        default: false
        }
    }

    private var centersHorizontally: Bool {
        layoutName == .title
    }

    private func placeholderType(_ element: PageElement) -> PlaceholderType? {
        element.shape?.placeholder?.type ?? element.image?.placeholder?.type
    }

    private var titles: [PageElement] {
        elements.filter { [.title, .centeredTitle].contains(placeholderType($0) ?? .none) }
    }

    private var subtitles: [PageElement] {
        elements.filter { placeholderType($0) == .subtitle }
    }

    private var contents: [PageElement] {
        elements.filter { element in
            let type = placeholderType(element) ?? .none
            return ![.title, .centeredTitle, .subtitle].contains(type)
        }
    }
}

/// 最小限のクロスプラットフォームプレゼンテーションコンテナ。現在のスライド + ページャーコントロール。
/// 独自クロームを持つアプリは GSlidesSlideView を直接使用する。
public struct GSlidesPresentationView: View {
    public var presentation: Presentation
    public var basePalette: (any ColorPalette)?
    @State private var index = 0

    public init(presentation: Presentation, basePalette: (any ColorPalette)? = nil) {
        self.presentation = presentation
        self.basePalette = basePalette
    }

    private var slides: [Page] { presentation.slides ?? [] }

    public var body: some View {
        VStack(spacing: 12) {
            if slides.indices.contains(index) {
                GSlidesSlideView(slide: slides[index], presentation: presentation, basePalette: basePalette)
                    .shadow(radius: 4)
            } else {
                ContentUnavailableView("No slides", systemImage: "rectangle.on.rectangle.slash")
            }
            if slides.count > 1 {
                HStack(spacing: 16) {
                    Button {
                        index = max(0, index - 1)
                    } label: {
                        SwiftUI.Image(systemName: "chevron.left")
                    }
                    .disabled(index == 0)
                    Text("\(index + 1) / \(slides.count)")
                        .font(.caption)
                        .monospacedDigit()
                    Button {
                        index = min(slides.count - 1, index + 1)
                    } label: {
                        SwiftUI.Image(systemName: "chevron.right")
                    }
                    .disabled(index == slides.count - 1)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
