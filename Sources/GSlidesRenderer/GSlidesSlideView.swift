import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Renders one slide on a fixed-aspect canvas (the presentation's page size).
/// Elements carrying geometry (size + transform, possibly inherited from their
/// layout) are placed absolutely in page coordinates; semantic-tier elements
/// without geometry fall back to a placeholder-type-driven stack layout.
public struct GSlidesSlideView: View {
    public var slide: Page
    public var presentation: Presentation
    public var palette: GSlidesPalette

    public init(slide: Page, presentation: Presentation, palette: GSlidesPalette = GSlidesPalette()) {
        self.slide = slide
        self.presentation = presentation
        self.palette = palette
    }

    public var body: some View {
        let pageSize = PageGeometry.pageSize(of: presentation)
        GeometryReader { proxy in
            let emuScale = proxy.size.width / pageSize.width
            let pointScale = proxy.size.width / (pageSize.width / EMU.perPoint)
            let elements = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
            let positioned = elements.filter { PageGeometry.frame(of: $0) != nil }
            let flowing = elements.filter { PageGeometry.frame(of: $0) == nil }

            ZStack(alignment: .topLeading) {
                Color.white
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
    public var palette: GSlidesPalette
    @State private var index = 0

    public init(presentation: Presentation, palette: GSlidesPalette = GSlidesPalette()) {
        self.presentation = presentation
        self.palette = palette
    }

    private var slides: [Page] { presentation.slides ?? [] }

    public var body: some View {
        VStack(spacing: 12) {
            if slides.indices.contains(index) {
                GSlidesSlideView(slide: slides[index], presentation: presentation, palette: palette)
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
