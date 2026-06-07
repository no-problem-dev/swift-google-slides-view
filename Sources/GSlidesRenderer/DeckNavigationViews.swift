import GSlidesSchema
import SwiftUI

/// Horizontal carousel of slide thumbnails — the inline "deck section" representation.
/// Slides appear as they stream in; `isComplete == false` shows a trailing progress card.
public struct GSlidesCarouselView: View {
    public var presentation: Presentation
    public var isComplete: Bool
    public var palette: GSlidesPalette
    public var onSelect: ((Int) -> Void)?

    public init(
        presentation: Presentation,
        isComplete: Bool = true,
        palette: GSlidesPalette = GSlidesPalette(),
        onSelect: ((Int) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.isComplete = isComplete
        self.palette = palette
        self.onSelect = onSelect
    }

    private var slides: [Page] { presentation.slides ?? [] }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(slides.enumerated()), id: \.element.objectId) { index, slide in
                    Button {
                        onSelect?(index)
                    } label: {
                        GSlidesSlideView(slide: slide, presentation: presentation, palette: palette)
                            .frame(width: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("スライド \(index + 1)")
                }
                if !isComplete {
                    generatingCard
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }

    private var generatingCard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.4))
            .frame(width: 240)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                VStack(spacing: 6) {
                    ProgressView()
                    Text("生成中…").font(.caption).foregroundStyle(.secondary)
                }
            }
    }
}

/// Vertical reading view: slides stacked top-to-bottom. Tapping a slide hands its
/// index back (hosts present the fullscreen pager).
public struct GSlidesStackView: View {
    public var presentation: Presentation
    public var palette: GSlidesPalette
    public var onSelect: ((Int) -> Void)?

    public init(
        presentation: Presentation,
        palette: GSlidesPalette = GSlidesPalette(),
        onSelect: ((Int) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.palette = palette
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array((presentation.slides ?? []).enumerated()), id: \.element.objectId) { index, slide in
                    Button {
                        onSelect?(index)
                    } label: {
                        GSlidesSlideView(slide: slide, presentation: presentation, palette: palette)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("スライド \(index + 1)")
                }
            }
            .padding()
        }
    }
}

/// Fullscreen pager over the deck. Horizontal paging starting at `initialIndex`.
public struct GSlidesFullScreenView: View {
    public var presentation: Presentation
    public var palette: GSlidesPalette
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    public init(
        presentation: Presentation,
        initialIndex: Int = 0,
        palette: GSlidesPalette = GSlidesPalette()
    ) {
        self.presentation = presentation
        self.palette = palette
        _index = State(initialValue: initialIndex)
    }

    private var slides: [Page] { presentation.slides ?? [] }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            pager
            Button {
                dismiss()
            } label: {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("閉じる")
        }
        .overlay(alignment: .bottom) {
            if slides.count > 1 {
                Text("\(index + 1) / \(slides.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder private var pager: some View {
        #if os(iOS)
        TabView(selection: $index) {
            ForEach(Array(slides.enumerated()), id: \.element.objectId) { slideIndex, slide in
                GSlidesSlideView(slide: slide, presentation: presentation, palette: palette)
                    .padding(.horizontal, 8)
                    .tag(slideIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        VStack {
            if slides.indices.contains(index) {
                GSlidesSlideView(slide: slides[index], presentation: presentation, palette: palette)
                    .padding()
            }
            HStack(spacing: 24) {
                Button {
                    index = max(0, index - 1)
                } label: {
                    SwiftUI.Image(systemName: "chevron.left")
                }
                .disabled(index == 0)
                Button {
                    index = min(slides.count - 1, index + 1)
                } label: {
                    SwiftUI.Image(systemName: "chevron.right")
                }
                .disabled(index >= slides.count - 1)
            }
            .foregroundStyle(.white)
            .padding(.bottom)
        }
        #endif
    }
}
