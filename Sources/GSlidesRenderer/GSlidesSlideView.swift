import DesignSystem
import GSlidesLayout
import GSlidesSchema
import SwiftUI

/// Draws one slide on a fixed-aspect canvas matching the presentation's page size.
///
/// Elements that have geometry — their own `size` and `transform`, or one inherited from the layout
/// — are positioned absolutely in page coordinates. Elements with no geometry fall back to a stacked
/// layout driven by placeholder type, which is what a semantic deck that never went through the
/// layout template looks like.
///
/// The view scales to whatever width it is given; there is no minimum, so a thumbnail and a
/// full-screen slide use the same code path.
///
/// Colors come from the deck's own theme: the master, layout and slide `ColorScheme` chain is
/// projected onto a design-system palette, and slide content and surrounding chrome both read
/// `@Environment(\.colorPalette)`.
public struct GSlidesSlideView: View {
    public var slide: Page
    public var presentation: Presentation
    /// The design-system palette used for slots the presentation does not define.
    ///
    /// Leave nil to inherit the app's surrounding palette, which lets undefined slots and chrome
    /// follow the app's dark mode while the deck stays authoritative over its own canvas.
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

    /// The slide's backdrop: a stretched picture fill when the page defines one, otherwise a solid
    /// theme color. A picture that fails to load falls back to that same solid color.
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

    /// The slide's one-based position in the deck, matched by objectId, for SLIDE_NUMBER auto text.
    /// nil when the slide is not part of the presentation it is being drawn against.
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

/// Places elements that have no geometry, using the layout name as a hint.
///
/// Titles go at the top — centered for the cover, section and main-point layouts — subtitles below
/// them, and everything else side by side in the remaining space. Element order within each band is
/// the deck's order.
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

/// A minimal cross-platform container: the current slide plus previous/next controls.
///
/// Meant for a quick preview. It owns its own index, so the host cannot drive or observe the current
/// slide — an app with its own chrome should use `GSlidesSlideView` directly.
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
