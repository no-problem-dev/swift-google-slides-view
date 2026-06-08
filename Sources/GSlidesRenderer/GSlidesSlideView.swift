import DesignSystem
import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Renders one slide on a fixed-aspect canvas (the presentation's page size).
/// Elements carrying geometry (size + transform, possibly inherited from their
/// layout) are placed absolutely in page coordinates; semantic-tier elements
/// without geometry fall back to a placeholder-type-driven stack layout.
///
/// Colors come from the deck's theme: the master/layout/slide `ColorScheme` is
/// projected onto a DS `ColorPalette` (`DeckColorPalette`), which drives both the
/// slide content and any DS chrome via `@Environment(\.colorPalette)`.
public struct GSlidesSlideView: View {
    public var slide: Page
    public var presentation: Presentation
    /// Base DS palette for slots the deck doesn't define (defaults to light).
    public var basePalette: any ColorPalette

    public init(slide: Page, presentation: Presentation, basePalette: any ColorPalette = LightColorPalette()) {
        self.slide = slide
        self.presentation = presentation
        self.basePalette = basePalette
    }

    private var deckPalette: DeckColorPalette {
        DeckColorPalette(scheme: DeckTheme.colorScheme(for: slide, in: presentation), base: basePalette)
    }

    public var body: some View {
        let pageSize = PageGeometry.pageSize(of: presentation)
        let deckPalette = deckPalette
        let palette = GSlidesPalette(deck: deckPalette)
        GeometryReader { proxy in
            let emuScale = proxy.size.width / pageSize.width
            let pointScale = proxy.size.width / (pageSize.width / EMU.perPoint)
            let elements = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
            let positioned = elements.filter { PageGeometry.frame(of: $0) != nil }
            let flowing = elements.filter { PageGeometry.frame(of: $0) == nil }

            ZStack(alignment: .topLeading) {
                DeckTheme.backgroundColor(for: slide, in: presentation, palette: deckPalette)
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
        .aspectRatio(pageSize.width / pageSize.height, contentMode: .fit)
        .clipped()
        // Chrome that reads @Environment(\.colorPalette) (DS components) shares the deck's theme.
        .environment(\.colorPalette, deckPalette)
    }

    private var layoutName: PredefinedLayout? {
        guard let layoutPage = PlaceholderResolver.layoutPage(for: slide, in: presentation),
              let name = layoutPage.layoutProperties?.name
        else { return nil }
        return PredefinedLayout(rawValue: name)
    }
}

/// Layout-name-aware arrangement for geometry-less elements:
/// title band on top (centered for TITLE / SECTION_HEADER families),
/// bodies side by side, images filling remaining space.
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

/// Minimal cross-platform deck container: current slide + pager controls.
/// Apps with their own chrome should drive GSlidesSlideView directly.
public struct GSlidesDeckView: View {
    public var presentation: Presentation
    public var basePalette: any ColorPalette
    @State private var index = 0

    public init(presentation: Presentation, basePalette: any ColorPalette = LightColorPalette()) {
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
