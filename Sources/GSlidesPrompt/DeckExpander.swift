import GSlidesLayout
import GSlidesSchema

/// Expands the semantic layer into profile-conformant presentation JSON, applying `DeckTemplate`:
/// each slide element gets the template's placeholder geometry + default text style baked in (so
/// the renderer's geometry path places and styles it), the master carries the theme, and layout
/// pages mirror the placeholder geometry — exactly the shape a real `presentations.get` deck has.
public enum DeckExpander {
    public static func expand(_ deck: SemanticDeck) -> Presentation {
        var usedLayouts: [PredefinedLayout] = []
        var slides: [Page] = []

        for (index, slide) in deck.slides.enumerated() {
            let layout = resolvedLayout(of: slide)
            if !usedLayouts.contains(layout) {
                usedLayouts.append(layout)
            }
            slides.append(page(for: slide, layout: layout, index: index))
        }

        let layoutPages = DeckTemplate.layoutPages(used: usedLayouts.map { ($0, slots(for: $0)) })
        return Presentation(
            title: deck.title,
            slides: slides,
            layouts: layoutPages,
            masters: [DeckTemplate.master()]
        )
    }

    /// The placeholder slots a layout's pages declare (drives the synthesized layout pages).
    static func slots(for layout: PredefinedLayout) -> [(PlaceholderType, Int)] {
        switch layout {
        case .title: [(.centeredTitle, 0), (.subtitle, 0)]
        case .titleAndTwoColumns: [(.title, 0), (.body, 0), (.body, 1)]
        case .bigNumber, .mainPoint, .sectionTitleAndDescription: [(.title, 0), (.body, 0)]
        case .sectionHeader: [(.title, 0)]
        default: [(.title, 0), (.body, 0)]
        }
    }

    public static func resolvedLayout(of slide: SemanticSlide) -> PredefinedLayout {
        if let raw = slide.layout {
            return PredefinedLayout(rawValue: raw)
        }
        return LayoutMatcher.match(content(of: slide))
    }

    static func content(of slide: SemanticSlide) -> SlideContent {
        SlideContent(
            title: slide.title.map { SlideContent.Text($0, big: slide.big ?? false) },
            subtitle: slide.subtitle.map { SlideContent.Text($0) },
            bodies: (slide.bodies ?? []).map { body in
                SlideContent.Body(
                    text: SlideContent.Text(body.text ?? (body.bullets ?? []).joined(separator: "\n")),
                    imageCount: body.imageUrl == nil ? 0 : 1
                )
            }
        )
    }

    static func page(for slide: SemanticSlide, layout: PredefinedLayout, index: Int) -> Page {
        let slideId = "slide-\(index + 1)"
        // Decorations first (drawn under content): accent rules/bars + page number.
        var elements: [PageElement] = DeckTemplate.decorations(for: layout, slideId: slideId)
        if let footer = DeckTemplate.footer(slideId: slideId, number: index + 1, layout: layout) {
            elements.append(footer)
        }

        if let title = slide.title {
            let type: PlaceholderType = layout == .title ? .centeredTitle : .title
            elements.append(shape(slideId, "title", layout, type, 0, plainText(title)))
        }
        if let subtitle = slide.subtitle {
            elements.append(shape(slideId, "subtitle", layout, .subtitle, 0, plainText(subtitle)))
        }
        for (bodyIndex, body) in (slide.bodies ?? []).enumerated() {
            if let imageUrl = body.imageUrl {
                var image = PageElement(
                    objectId: "\(slideId)-image-\(bodyIndex)",
                    image: Image(sourceUrl: imageUrl, placeholder: Placeholder(type: .picture, index: bodyIndex))
                )
                if let spec = DeckTemplate.spec(layout: layout, type: .picture, index: bodyIndex) {
                    image.size = spec.size
                    image.transform = spec.transform
                }
                elements.append(image)
            }
            if let text = bodyText(body) {
                elements.append(shape(slideId, "body-\(bodyIndex)", layout, .body, bodyIndex, text))
            }
        }

        return Page(
            objectId: slideId,
            pageType: .slide,
            pageElements: elements,
            slideProperties: SlideProperties(layoutObjectId: DeckTemplate.layoutObjectId(layout), masterObjectId: DeckTemplate.masterObjectId)
        )
    }

    /// Builds a placeholder shape with the template's geometry + default style baked in. The slide
    /// element is fully specified (like a flattened real deck) so the renderer places and styles it
    /// without needing the semantic fallback. Falls back to a plain (geometry-less) shape if the
    /// template has no spec for this slot.
    static func shape(
        _ slideId: String, _ suffix: String, _ layout: PredefinedLayout,
        _ type: PlaceholderType, _ index: Int, _ text: TextContent
    ) -> PageElement {
        let id = "\(slideId)-\(suffix)"
        guard let spec = DeckTemplate.spec(layout: layout, type: type, index: index) else {
            return placeholderShape(id: id, type: type, index: index, text: text)
        }
        return PageElement(
            objectId: id,
            size: spec.size,
            transform: spec.transform,
            shape: Shape(
                shapeType: .textBox,
                text: styled(text, with: spec),
                placeholder: Placeholder(type: type, index: index),
                shapeProperties: ShapeProperties(contentAlignment: spec.vAlign)
            )
        )
    }

    /// Applies the spec's default text style + alignment to runs/paragraphs that don't set their own.
    static func styled(_ text: TextContent, with spec: PlaceholderSpec) -> TextContent {
        var text = text
        text.textElements = text.textElements?.map { element in
            var element = element
            if var run = element.textRun {
                var style = run.style ?? TextStyle()
                if style.fontSize == nil { style.fontSize = spec.defaultStyle.fontSize }
                if style.foregroundColor == nil { style.foregroundColor = spec.defaultStyle.foregroundColor }
                if style.bold == nil { style.bold = spec.bold }
                run.style = style
                element.textRun = run
            }
            var marker = element.paragraphMarker ?? ParagraphMarker()
            var pStyle = marker.style ?? ParagraphStyle()
            if pStyle.alignment == nil { pStyle.alignment = spec.align }
            marker.style = pStyle
            element.paragraphMarker = marker
            return element
        }
        return text
    }

    static func bodyText(_ body: SemanticBody) -> TextContent? {
        if let bullets = body.bullets, !bullets.isEmpty {
            return TextContent(textElements: bullets.map { bullet in
                TextElement(
                    paragraphMarker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: "●")),
                    textRun: TextRun(content: bullet + "\n")
                )
            })
        }
        if let text = body.text, !text.isEmpty {
            return plainText(text)
        }
        return nil
    }

    static func plainText(_ text: String) -> TextContent {
        TextContent(textElements: [
            TextElement(paragraphMarker: ParagraphMarker(), textRun: TextRun(content: text + "\n"))
        ])
    }

    static func placeholderShape(
        id: String,
        type: PlaceholderType,
        index: Int = 0,
        text: TextContent
    ) -> PageElement {
        PageElement(
            objectId: id,
            shape: Shape(
                shapeType: .textBox,
                text: text,
                placeholder: Placeholder(type: type, index: index)
            )
        )
    }
}
