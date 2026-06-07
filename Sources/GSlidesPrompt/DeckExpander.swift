import GSlidesLayout
import GSlidesSchema

/// Expands the semantic layer into profile-conformant presentation JSON:
/// one synthesized layout page per used predefined layout (named after it,
/// as in real presentations), slides referencing them via slideObjectId,
/// placeholder shapes carrying the content. Geometry stays absent — the
/// semantic tier delegates positioning to the renderer's layout defaults.
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

        let layoutPages = usedLayouts.map { layout in
            Page(
                objectId: layoutObjectId(layout),
                pageType: .layout,
                layoutProperties: LayoutProperties(name: layout.rawValue)
            )
        }
        return Presentation(title: deck.title, slides: slides, layouts: layoutPages)
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

    static func layoutObjectId(_ layout: PredefinedLayout) -> String {
        "layout-\(layout.rawValue)"
    }

    static func page(for slide: SemanticSlide, layout: PredefinedLayout, index: Int) -> Page {
        let slideId = "slide-\(index + 1)"
        var elements: [PageElement] = []

        if let title = slide.title {
            let type: PlaceholderType = layout == .title ? .centeredTitle : .title
            elements.append(placeholderShape(id: "\(slideId)-title", type: type, text: plainText(title)))
        }
        if let subtitle = slide.subtitle {
            elements.append(placeholderShape(id: "\(slideId)-subtitle", type: .subtitle, text: plainText(subtitle)))
        }
        for (bodyIndex, body) in (slide.bodies ?? []).enumerated() {
            if let imageUrl = body.imageUrl {
                elements.append(PageElement(
                    objectId: "\(slideId)-image-\(bodyIndex)",
                    image: Image(sourceUrl: imageUrl, placeholder: Placeholder(type: .picture, index: bodyIndex))
                ))
            }
            if let text = bodyText(body) {
                elements.append(placeholderShape(
                    id: "\(slideId)-body-\(bodyIndex)",
                    type: .body,
                    index: bodyIndex,
                    text: text
                ))
            }
        }

        return Page(
            objectId: slideId,
            pageType: .slide,
            pageElements: elements,
            slideProperties: SlideProperties(layoutObjectId: layoutObjectId(layout))
        )
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
