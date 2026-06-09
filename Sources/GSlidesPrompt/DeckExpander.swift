import GSlidesLayout
import GSlidesSchema

/// Expands the semantic layer into profile-conformant presentation JSON, applying `DeckTemplate`:
/// each slide element gets the template's placeholder geometry + default text style baked in (so
/// the renderer's geometry path places and styles it), the master carries the theme, and layout
/// pages mirror the placeholder geometry — exactly the shape a real `presentations.get` deck has.
public enum DeckExpander {
    /// `theme` is the default/seed; a deck's own `theme` hint (if any) overrides it. Either way the
    /// chosen theme is baked into the single master `ColorScheme` (the document's theme).
    public static func expand(_ deck: SemanticDeck, theme: DeckColorTheme = .light) -> Presentation {
        let effectiveTheme = deck.theme.flatMap(DeckColorTheme.init(rawValue:)) ?? theme
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
            masters: [DeckTemplate.master(theme: effectiveTheme)]
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
                    text: SlideContent.Text(body.text ?? bodyMatchText(body)),
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
            elements.append(titleShape(slideId, "title", layout, type, plainText(title)))
        }
        if let subtitle = slide.subtitle {
            elements.append(titleShape(slideId, "subtitle", layout, .subtitle, plainText(subtitle)))
        }
        // Title / section slides are title-only by design — drop any stray image the model added.
        let allowsImages = ![.title, .sectionHeader].contains(layout)
        let bodies = slide.bodies ?? []
        // Multiple bodies on a single-column layout = multiple columns (TITLE_AND_TWO_COLUMNS already
        // carries per-index geometry; others reuse the same full rect, so divide it here). Without
        // this, two bodies — e.g. a text body and an image body — land in the same rect and overlap.
        let bodyRegion = DeckTemplate.spec(layout: layout, type: .body, index: 0)
        let useColumns = bodies.count > 1 && layout != .titleAndTwoColumns && bodyRegion != nil
        let columnSpecs = useColumns ? DeckTemplate.columns(of: bodyRegion!, count: bodies.count) : []
        for (bodyIndex, body) in bodies.enumerated() {
            let text = bodyText(body)
            let imageUrl = allowsImages ? body.imageUrl : nil
            let resolvedSpec = useColumns ? columnSpecs[bodyIndex] : DeckTemplate.spec(layout: layout, type: .body, index: bodyIndex)
            guard let bodySpec = resolvedSpec else {
                if let table = body.table {
                    elements.append(tableElement(id: "\(slideId)-table-\(bodyIndex)", rect: nil, table: table))
                } else if let text {
                    elements.append(placeholderShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, text: text))
                }
                continue
            }

            // A table occupies its whole body box (text/image are mutually exclusive with it).
            if let table = body.table {
                elements.append(tableElement(id: "\(slideId)-table-\(bodyIndex)", rect: bodySpec, table: table))
                continue
            }

            switch (text, imageUrl) {
            case let (.some(text), .some(url)):
                // Split the body box: text left, image right (no overlap).
                let (textSpec, imageRect) = splitLeftRight(bodySpec)
                elements.append(styledShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, spec: textSpec, text: text))
                elements.append(imageElement(id: "\(slideId)-image-\(bodyIndex)", index: bodyIndex, rect: imageRect, url: url))
            case let (.some(text), .none):
                elements.append(styledShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, spec: bodySpec, text: text))
            case let (.none, .some(url)):
                elements.append(imageElement(id: "\(slideId)-image-\(bodyIndex)", index: bodyIndex, rect: bodySpec, url: url))
            case (.none, .none):
                break
            }
        }

        return Page(
            objectId: slideId,
            pageType: .slide,
            pageElements: elements,
            slideProperties: SlideProperties(layoutObjectId: DeckTemplate.layoutObjectId(layout), masterObjectId: DeckTemplate.masterObjectId)
        )
    }

    /// Title / subtitle shape from the template spec (or a plain shape if no spec).
    static func titleShape(
        _ slideId: String, _ suffix: String, _ layout: PredefinedLayout,
        _ type: PlaceholderType, _ text: TextContent
    ) -> PageElement {
        let id = "\(slideId)-\(suffix)"
        guard let spec = DeckTemplate.spec(layout: layout, type: type, index: 0) else {
            return placeholderShape(id: id, type: type, index: 0, text: text)
        }
        return styledShape(id: id, type: type, index: 0, spec: spec, text: text)
    }

    /// A fully-specified placeholder shape: geometry + default style baked in (like a flattened real
    /// deck) so the renderer places and styles it without the semantic fallback.
    static func styledShape(id: String, type: PlaceholderType, index: Int, spec: PlaceholderSpec, text: TextContent) -> PageElement {
        PageElement(
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

    static func imageElement(id: String, index: Int, rect: PlaceholderSpec, url: String) -> PageElement {
        PageElement(
            objectId: id,
            size: rect.size,
            transform: rect.transform,
            image: Image(sourceUrl: url, placeholder: Placeholder(type: .picture, index: index))
        )
    }

    /// Splits a body box into a text column (left, ~55%) and an image rect (right).
    static func splitLeftRight(_ spec: PlaceholderSpec) -> (text: PlaceholderSpec, image: PlaceholderSpec) {
        let gap = 360_000.0
        let leftW = (spec.w - gap) * 0.55
        let rightW = spec.w - gap - leftW
        var text = spec; text.w = leftW
        var image = spec; image.x = spec.x + leftW + gap; image.w = rightW
        return (text, image)
    }

    /// Applies the spec's default text style + alignment to runs/paragraphs that don't set their own.
    /// Only fills nil fields, so inline emphasis (bold / accent runs) is preserved. Paragraph style
    /// is set only on elements that already open a paragraph — run-only elements (extra inline runs)
    /// are left as runs so the renderer keeps them on the same line.
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
            if var marker = element.paragraphMarker {
                var pStyle = marker.style ?? ParagraphStyle()
                if pStyle.alignment == nil { pStyle.alignment = spec.align }
                marker.style = pStyle
                element.paragraphMarker = marker
            }
            return element
        }
        return text
    }

    static func bodyText(_ body: SemanticBody) -> TextContent? {
        if let bullets = body.bullets, !bullets.isEmpty {
            return TextContent(textElements: bullets.flatMap { bullet in
                paragraphElements(
                    marker: ParagraphMarker(bullet: Bullet(nestingLevel: bullet.level, glyph: bulletGlyph(for: bullet.level))),
                    runs: inlineRuns(bullet.text)
                )
            })
        }
        if let text = body.text, !text.isEmpty {
            return plainText(text)
        }
        return nil
    }

    /// Glyph per nesting level — a visual hierarchy for multi-level lists (renderer also indents).
    static func bulletGlyph(for level: Int) -> String {
        switch level {
        case 0: "●"
        case 1: "○"
        default: "▪"
        }
    }

    /// Flattened text for layout matching (bullets + table cells), so a table-bearing body still
    /// reads as content.
    static func bodyMatchText(_ body: SemanticBody) -> String {
        let bullets = (body.bullets ?? []).map(\.text).joined(separator: "\n")
        return [bullets, tableText(body.table)].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func tableText(_ table: SemanticTable?) -> String {
        guard let table else { return "" }
        let rows = (table.headers.map { [$0] } ?? []) + table.rows
        return rows.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    /// A profile `Table` element from the semantic table: header row (if any) first and emphasized,
    /// ragged rows padded to the widest. `rect` nil → no baked geometry (renderer flows it).
    static func tableElement(id: String, rect: PlaceholderSpec?, table: SemanticTable) -> PageElement {
        let allRows = (table.headers.map { [$0] } ?? []) + table.rows
        let columns = allRows.map(\.count).max() ?? 0
        let hasHeader = table.headers != nil
        let tableRows: [TableRow] = allRows.enumerated().map { rowIndex, cells in
            let isHeader = hasHeader && rowIndex == 0
            let style = TextStyle(
                bold: isHeader ? true : nil,
                foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: isHeader ? .accent1 : .text1))
            )
            // Header row gets a subtle tinted background (the renderer draws cell fills).
            let cellProps = isHeader
                ? TableCellProperties(tableCellBackgroundFill: TableCellBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: .light2))), contentAlignment: .middle)
                : TableCellProperties(contentAlignment: .middle)
            let tableCells: [TableCell] = (0..<columns).map { column in
                let content = column < cells.count ? cells[column] : ""
                return TableCell(
                    location: TableCellLocation(rowIndex: rowIndex, columnIndex: column),
                    rowSpan: 1,
                    columnSpan: 1,
                    text: TextContent(textElements: [TextElement(
                        paragraphMarker: ParagraphMarker(),
                        textRun: TextRun(content: content + "\n", style: style))]),
                    tableCellProperties: cellProps
                )
            }
            return TableRow(rowHeight: nil, tableCells: tableCells)
        }
        return PageElement(
            objectId: id,
            size: rect?.size,
            transform: rect?.transform,
            table: Table(rows: allRows.count, columns: columns, tableRows: tableRows)
        )
    }

    static func plainText(_ text: String) -> TextContent {
        TextContent(textElements: paragraphElements(marker: ParagraphMarker(), runs: inlineRuns(text)))
    }

    /// One paragraph's elements: the marker opens it (carrying the first run, compact form), and any
    /// further inline runs follow as run-only elements on the same line. The trailing newline marks
    /// the paragraph end.
    static func paragraphElements(marker: ParagraphMarker, runs: [TextRun]) -> [TextElement] {
        guard var last = runs.last else { return [TextElement(paragraphMarker: marker)] }
        var runs = runs
        last.content = (last.content ?? "") + "\n"
        runs[runs.count - 1] = last
        var elements = [TextElement(paragraphMarker: marker, textRun: runs[0])]
        elements.append(contentsOf: runs.dropFirst().map { TextElement(textRun: $0) })
        return elements
    }

    /// Parses lightweight inline markup into styled runs: `**bold**` → bold, `==accent==` → an
    /// accent-colored emphasis. Plain spans carry no style (the placeholder default fills them).
    static func inlineRuns(_ text: String) -> [TextRun] {
        enum Emphasis { case none, bold, accent }
        func style(_ e: Emphasis) -> TextStyle? {
            switch e {
            case .none: nil
            case .bold: TextStyle(bold: true)
            case .accent: TextStyle(bold: true, foregroundColor: OptionalColor(opaqueColor: OpaqueColor(themeColor: .accent1)))
            }
        }
        var runs: [TextRun] = []
        var buffer = ""
        var emphasis: Emphasis = .none
        func flush() {
            if !buffer.isEmpty { runs.append(TextRun(content: buffer, style: style(emphasis))); buffer = "" }
        }
        var index = text.startIndex
        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("**") {
                flush(); emphasis = emphasis == .bold ? .none : .bold
                index = text.index(index, offsetBy: 2)
            } else if rest.hasPrefix("==") {
                flush(); emphasis = emphasis == .accent ? .none : .accent
                index = text.index(index, offsetBy: 2)
            } else {
                buffer.append(text[index]); index = text.index(after: index)
            }
        }
        flush()
        return runs.isEmpty ? [TextRun(content: "")] : runs
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
