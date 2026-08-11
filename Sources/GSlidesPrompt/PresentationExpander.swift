import GSlidesLayout
import GSlidesSchema

/// Expands a semantic deck into a full presentation with geometry baked in.
///
/// Applies `PresentationTemplate`, writing each element's placeholder rectangle and default text
/// style onto the element itself, so the renderer's absolute-positioning path handles it and never
/// falls back to the stacked semantic layout. The output carries a master holding the theme and
/// layout pages mirroring the placeholder geometry — the same shape a real `presentations.get`
/// returns, which is what makes a generated deck round-trip to the API.
public enum PresentationExpander {
    /// Expands semantic content against a color intent.
    ///
    /// The palette is baked into a single master's color scheme, and every placeholder and
    /// decoration references its slots symbolically, so swapping the theme recolors the whole deck.
    /// The theme is always supplied, never inferred from the content.
    public static func expand(
        _ presentation: SemanticPresentation,
        themeSpec: ThemeSpec = .light,
        typography: PresentationTypography = .system,
        design: SlideDesignSystem = .standard
    ) -> Presentation {
        var usedLayouts: [PredefinedLayout] = []
        var slides: [Page] = []

        for (index, slide) in presentation.slides.enumerated() {
            let layout = resolvedLayout(of: slide)
            if !usedLayouts.contains(layout) {
                usedLayouts.append(layout)
            }
            slides.append(page(for: slide, layout: layout, index: index, typography: typography, design: design, deckTitle: presentation.title))
        }

        let layoutPages = PresentationTemplate.layoutPages(used: usedLayouts.map { ($0, slots(for: $0)) }, typography: typography, scale: design.scale)
        return Presentation(
            title: presentation.title,
            slides: slides,
            layouts: layoutPages,
            masters: [PresentationTemplate.master(theme: themeSpec)]
        )
    }

    /// The placeholder slots a layout declares, used to emit the synthetic layout pages.
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

    static func page(
        for slide: SemanticSlide,
        layout: PredefinedLayout,
        index: Int,
        typography: PresentationTypography = .system,
        design: SlideDesignSystem = .standard,
        deckTitle: String? = nil
    ) -> Page {
        let slideId = "slide-\(index + 1)"
        let scale = design.scale
        // Decorations first (drawn under content): accent rules/bars + page number.
        var elements: [PageElement] = PresentationTemplate.decorations(for: layout, slideId: slideId, scale: scale)
        elements.append(contentsOf: PresentationTemplate.footer(slideId: slideId, number: index + 1, layout: layout, typography: typography, deckTitle: deckTitle, scale: scale))

        if let title = slide.title {
            if design.headerStyle == .eyebrowHeadline, PresentationTemplate.usesContentHeader(layout) {
                elements.append(contentHeaderShape(slideId, layout, title, typography: typography, scale: scale))
            } else {
                let type: PlaceholderType = layout == .title ? .centeredTitle : .title
                elements.append(titleShape(slideId, "title", layout, type, plainText(title), typography: typography, scale: scale))
            }
        }
        if let subtitle = slide.subtitle {
            elements.append(titleShape(slideId, "subtitle", layout, .subtitle, plainText(subtitle), typography: typography, scale: scale))
        }
        // Title / section slides are title-only by design — drop any stray image the model added.
        let allowsImages = ![.title, .sectionHeader].contains(layout)
        let bodies = slide.bodies ?? []
        // Multiple bodies on a single-column layout = multiple columns (TITLE_AND_TWO_COLUMNS already
        // carries per-index geometry; others reuse the same full rect, so divide it here). Without
        // this, two bodies — e.g. a text body and an image body — land in the same rect and overlap.
        let bodyRegion = PresentationTemplate.spec(layout: layout, type: .body, index: 0, typography: typography, scale: scale)
        let useColumns = bodies.count > 1 && layout != .titleAndTwoColumns && bodyRegion != nil
        let columnSpecs = useColumns ? PresentationTemplate.columns(of: bodyRegion!, count: bodies.count) : []
        for (bodyIndex, body) in bodies.enumerated() {
            let text = bodyText(body)
            let imageUrl = allowsImages ? body.imageUrl : nil
            let resolvedSpec = useColumns ? columnSpecs[bodyIndex] : PresentationTemplate.spec(layout: layout, type: .body, index: bodyIndex, typography: typography, scale: scale)
            guard let bodySpec = resolvedSpec else {
                if let table = body.table {
                    elements.append(tableElement(id: "\(slideId)-table-\(bodyIndex)", rect: nil, table: table))
                } else if let metrics = body.metrics, !metrics.isEmpty {
                    // No body geometry to draw the stat strip in → degrade to a labeled text list.
                    elements.append(placeholderShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, text: metricsFallbackText(metrics)))
                } else if let chart = body.chart, chart.bars.count >= 2 {
                    // No geometry to plot the chart → degrade to a labeled text list of the bars.
                    elements.append(placeholderShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, text: chartFallbackText(chart)))
                } else if let steps = body.steps, steps.count >= 2 {
                    // No geometry to lay out cards → degrade to a numbered step list.
                    elements.append(placeholderShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, text: stepsFallbackText(steps)))
                } else if let quote = body.quote, !quote.text.isEmpty {
                    // No geometry → degrade to the quote text as a plain body.
                    elements.append(placeholderShape(id: "\(slideId)-body-\(bodyIndex)", type: .body, index: bodyIndex, text: plainText(quoteFallbackText(quote))))
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

            // Metrics occupy the whole body box as a stat strip (also mutually exclusive).
            if let metrics = body.metrics, !metrics.isEmpty {
                elements.append(contentsOf: metricElements(slideId: slideId, bodyIndex: bodyIndex, rect: bodySpec, metrics: metrics))
                continue
            }

            // A chart occupies the whole body box as a native column chart (also mutually exclusive).
            if let chart = body.chart, chart.bars.count >= 2 {
                elements.append(contentsOf: chartElements(slideId: slideId, bodyIndex: bodyIndex, rect: bodySpec, chart: chart))
                continue
            }

            // A process flow occupies the whole body box as arrow-joined step cards (also exclusive).
            if let steps = body.steps, steps.count >= 2 {
                elements.append(contentsOf: stepElements(slideId: slideId, bodyIndex: bodyIndex, rect: bodySpec, steps: steps))
                continue
            }

            // A testimonial occupies the whole body box as a pull quote (also exclusive).
            if let quote = body.quote, !quote.text.isEmpty {
                elements.append(contentsOf: quoteElements(slideId: slideId, bodyIndex: bodyIndex, rect: bodySpec, quote: quote))
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
            slideProperties: SlideProperties(layoutObjectId: PresentationTemplate.layoutObjectId(layout), masterObjectId: PresentationTemplate.masterObjectId)
        )
    }

    /// A content slide's header: one TITLE placeholder holding an eyebrow paragraph above a headline.
    ///
    /// The eyebrow is the label half of a "Label: conclusion" title, set small and in the accent
    /// color. Two paragraphs in one placeholder is Slides-native, so this round-trips to the real
    /// API. A title with no colon separator falls back to a single headline.
    static func contentHeaderShape(
        _ slideId: String, _ layout: PredefinedLayout, _ title: String,
        typography: PresentationTypography = .system,
        scale: SpacingScale = .content
    ) -> PageElement {
        let id = "\(slideId)-title"
        let spec = PresentationTemplate.spec(layout: layout, type: .title, index: 0, typography: typography, scale: scale)
            ?? PresentationTemplate.contentHeadlineSpec(scale: scale)
        guard let (label, headline) = splitLabelTitle(title) else {
            return styledShape(id: id, type: .title, index: 0, spec: spec, text: plainText(title))
        }
        let eyebrowStyle = PresentationTemplate.eyebrowStyle(typography: typography, scale: scale)
        let gap = Dimension(magnitude: scale.eyebrowGapPt, unit: .pt)
        let text = TextContent(textElements: [
            TextElement(
                paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start, spaceBelow: gap)),
                textRun: TextRun(content: label, style: eyebrowStyle)
            ),
            TextElement(
                paragraphMarker: ParagraphMarker(style: ParagraphStyle(alignment: .start)),
                textRun: TextRun(content: headline, style: nil)
            ),
        ])
        return styledShape(id: id, type: .title, index: 0, spec: spec, text: text)
    }

    /// Splits a "Label: conclusion" title at the first full-width or ASCII colon.
    ///
    /// - Returns: nil when there is no separator, or when either half is empty after trimming, which
    ///   the caller draws as a single headline.
    static func splitLabelTitle(_ title: String) -> (label: String, headline: String)? {
        for separator in ["：", ":"] {
            if let range = title.range(of: separator) {
                let label = title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let headline = title[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !label.isEmpty, !headline.isEmpty { return (label, headline) }
            }
        }
        return nil
    }

    /// A title or subtitle shape built from the template spec, or a plain unpositioned placeholder
    /// when this layout defines no such slot.
    static func titleShape(
        _ slideId: String, _ suffix: String, _ layout: PredefinedLayout,
        _ type: PlaceholderType, _ text: TextContent,
        typography: PresentationTypography = .system,
        scale: SpacingScale = .content
    ) -> PageElement {
        let id = "\(slideId)-\(suffix)"
        guard let spec = PresentationTemplate.spec(layout: layout, type: type, index: 0, typography: typography, scale: scale) else {
            return placeholderShape(id: id, type: type, index: 0, text: text)
        }
        return styledShape(id: id, type: type, index: 0, spec: spec, text: text)
    }

    /// A fully specified placeholder shape with geometry and default style baked in, the way a real
    /// presentation looks once flattened. The renderer positions it directly, with no fallback.
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

    /// Splits a body box into a text column on the left, roughly 55%, and an image rect on the right.
    static func splitLeftRight(_ spec: PlaceholderSpec) -> (text: PlaceholderSpec, image: PlaceholderSpec) {
        let gap = 360_000.0
        let leftW = (spec.w - gap) * 0.55
        let rightW = spec.w - gap - leftW
        var text = spec; text.w = leftW
        var image = spec; image.x = spec.x + leftW + gap; image.w = rightW
        return (text, image)
    }

    // MARK: - Metrics (native stat-card visual, composed from text + filled bars — no image)

    /// Expands metrics into a row of stat cards spanning the body rect.
    ///
    /// Each card is a large accent value with an optional smaller unit, a muted label beneath it, and
    /// a proportional bar when `ratio` is set. Composed entirely of text and filled rectangles, so
    /// the existing geometry renderer draws it with no new element type. Cards share the width
    /// evenly, so many metrics produce narrow columns rather than wrapping.
    static func metricElements(slideId: String, bodyIndex: Int, rect: PlaceholderSpec, metrics: [SemanticMetric]) -> [PageElement] {
        let columns = PresentationTemplate.columns(of: rect, count: metrics.count, gap: 360_000)
        let valueH = 1_150_000.0
        let labelH = 520_000.0
        let barH = 84_000.0
        var elements: [PageElement] = []
        for (i, metric) in metrics.enumerated() {
            let col = columns[i]
            let idBase = "\(slideId)-metric-\(bodyIndex)-\(i)"

            // Value (+ optional smaller unit), large accent, top of the column. The value size steps
            // down for longer numbers ("1,200") so value + unit stay on one line instead of wrapping.
            let valueSize: Double = metric.value.count <= 3 ? 52 : (metric.value.count <= 5 ? 42 : 34)
            var valueSpec = col
            valueSpec.h = valueH
            valueSpec.fontSizePt = valueSize
            valueSpec.themeColor = .accent1
            valueSpec.bold = true
            valueSpec.align = .start
            valueSpec.vAlign = .bottom
            var runs = [TextRun(content: metric.value, style: nil)]
            if let unit = metric.unit, !unit.isEmpty {
                runs.append(TextRun(content: " " + unit, style: TextStyle(fontSize: Dimension(magnitude: max(16, valueSize * 0.42), unit: .pt))))
            }
            let valueText = TextContent(textElements: paragraphElements(marker: ParagraphMarker(), runs: runs))
            elements.append(textBox(id: "\(idBase)-value", spec: valueSpec, text: valueText))

            // Label, muted, beneath the value.
            var labelSpec = col
            labelSpec.y = col.y + valueH + 60_000
            labelSpec.h = labelH
            labelSpec.fontSizePt = 16
            labelSpec.themeColor = .dark2
            labelSpec.bold = false
            labelSpec.align = .start
            labelSpec.vAlign = .top
            elements.append(textBox(id: "\(idBase)-label", spec: labelSpec, text: plainText(metric.label)))

            // Optional proportional bar (track + accent fill).
            if let ratio = metric.ratio {
                let clamped = min(max(ratio, 0), 1)
                let barY = labelSpec.y + labelH + 40_000
                elements.append(fillRect(id: "\(idBase)-track", x: col.x, y: barY, w: col.w, h: barH, color: .light2))
                if clamped > 0 {
                    elements.append(fillRect(id: "\(idBase)-fill", x: col.x, y: barY, w: col.w * clamped, h: barH, color: .accent1))
                }
            }
        }
        return elements
    }

    /// A standalone styled text box with no placeholder — the value and label text inside a visual,
    /// which is not a semantic placeholder. Runs inherit the spec's size, color and weight.
    static func textBox(id: String, spec: PlaceholderSpec, text: TextContent) -> PageElement {
        PageElement(
            objectId: id,
            size: spec.size,
            transform: spec.transform,
            shape: Shape(
                shapeType: .textBox,
                text: styled(text, with: spec),
                shapeProperties: ShapeProperties(contentAlignment: spec.vAlign)
            )
        )
    }

    /// A filled rectangle at an EMU position, drawn by the renderer as a shape background fill.
    static func fillRect(id: String, x: Double, y: Double, w: Double, h: Double, color: ThemeColorType) -> PageElement {
        PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu),
            shape: Shape(
                shapeType: .rectangle,
                shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: color))))
            )
        )
    }

    /// The degraded form used when the layout gives the body no geometry: one bullet per statistic,
    /// as "label: value unit". The numbers survive; the visual does not.
    static func metricsFallbackText(_ metrics: [SemanticMetric]) -> TextContent {
        TextContent(textElements: metrics.flatMap { metric in
            let unit = metric.unit.map { " " + $0 } ?? ""
            return paragraphElements(
                marker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: bulletGlyph(for: 0))),
                runs: inlineRuns("\(metric.label): \(metric.value)\(unit)")
            )
        })
    }

    // MARK: - Chart (native single-series column chart, composed from filled bars + labels — no image)

    /// Expands a chart into the body rect: proportional accent bars on a baseline, a value caption
    /// above each, and category labels beneath.
    ///
    /// Bars are sized against the series' own maximum, so there is no axis and two charts are not
    /// comparable. Composed of filled rectangles and text, so the geometry renderer draws it.
    static func chartElements(slideId: String, bodyIndex: Int, rect: PlaceholderSpec, chart: SemanticChart) -> [PageElement] {
        let bars = chart.bars
        let valueLabelH = 320_000.0
        let categoryLabelH = 320_000.0
        let gap = 200_000.0
        let plotTop = rect.y + valueLabelH
        let plotBottom = rect.y + rect.h - categoryLabelH
        let plotH = max(plotBottom - plotTop, 1)
        let maxValue = max(bars.map(\.value).max() ?? 0, .ulpOfOne)
        let slotW = (rect.w - gap * Double(bars.count - 1)) / Double(bars.count)
        let prefix = "\(slideId)-chart-\(bodyIndex)"
        func slotX(_ i: Int) -> Double { rect.x + (slotW + gap) * Double(i) }
        func pointY(_ value: Double) -> Double { plotBottom - plotH * max(value, 0) / maxValue }

        var elements: [PageElement] = []
        // Faint horizontal gridlines (half + full of max) behind the data — a subtle reference grid.
        for frac in [0.5, 1.0] {
            elements.append(fillRect(id: "\(prefix)-grid-\(Int(frac * 100))", x: rect.x, y: plotBottom - plotH * frac, w: rect.w, h: 6_000, color: .light2))
        }
        // Baseline rule under the plot (slightly heavier than the gridlines).
        elements.append(fillRect(id: "\(prefix)-base", x: rect.x, y: plotBottom, w: rect.w, h: 18_000, color: .light2))

        // Value caption (accent, above the bar/point) for a data point at `anchorY`.
        func valueLabel(_ i: Int, _ bar: SemanticChartBar, anchorY: Double) {
            var spec = rect
            spec.x = slotX(i); spec.y = max(rect.y, anchorY - valueLabelH); spec.w = slotW; spec.h = valueLabelH
            spec.fontSizePt = 16; spec.themeColor = .accent1; spec.bold = true
            spec.align = .center; spec.vAlign = .bottom
            elements.append(textBox(id: "\(prefix)-\(i)-value", spec: spec, text: plainText(bar.caption ?? formatValue(bar.value))))
        }

        // Category labels beneath the baseline (shared by both chart types).
        for (i, bar) in bars.enumerated() {
            var labelSpec = rect
            labelSpec.x = slotX(i); labelSpec.y = plotBottom + 40_000; labelSpec.w = slotW; labelSpec.h = categoryLabelH
            labelSpec.fontSizePt = 14; labelSpec.themeColor = .dark2; labelSpec.bold = false
            labelSpec.align = .center; labelSpec.vAlign = .top
            elements.append(textBox(id: "\(prefix)-\(i)-label", spec: labelSpec, text: plainText(bar.label)))
        }

        switch chart.type {
        case .bar:
            let barW = slotW * 0.62
            for (i, bar) in bars.enumerated() {
                let barH = plotH * max(bar.value, 0) / maxValue
                let barY = plotBottom - barH
                if barH > 0 {
                    elements.append(fillRect(id: "\(prefix)-\(i)-bar", x: slotX(i) + (slotW - barW) / 2, y: barY, w: barW, h: barH, color: .accent1))
                }
                valueLabel(i, bar, anchorY: barY)
            }
        case .line:
            let dotD = 96_000.0
            // Connecting segments between consecutive points (ascending segments flip vertically).
            for i in 0..<(bars.count - 1) {
                let x1 = slotX(i) + slotW / 2, y1 = pointY(bars[i].value)
                let x2 = slotX(i + 1) + slotW / 2, y2 = pointY(bars[i + 1].value)
                elements.append(lineSegment(id: "\(prefix)-\(i)-seg", x1: x1, y1: y1, x2: x2, y2: y2, weightPt: 2.5, color: .accent1))
            }
            // Markers + value captions at each point.
            for (i, bar) in bars.enumerated() {
                let cx = slotX(i) + slotW / 2, cy = pointY(bar.value)
                elements.append(dot(id: "\(prefix)-\(i)-dot", cx: cx, cy: cy, d: dotD, color: .accent1))
                valueLabel(i, bar, anchorY: cy - dotD / 2)
            }
        }
        return elements
    }

    /// A filled circular marker centered on a point — a data point of a line chart.
    static func dot(id: String, cx: Double, cy: Double, d: Double, color: ThemeColorType) -> PageElement {
        PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: d, unit: .emu), height: Dimension(magnitude: d, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: cx - d / 2, translateY: cy - d / 2, unit: .emu),
            shape: Shape(
                shapeType: .ellipse,
                shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: color))))
            )
        )
    }

    /// A straight segment between two points, as a `Line` element.
    ///
    /// A line element only ever draws a diagonal of its box, so a rising segment is encoded as a
    /// vertical flip — a negative scaleY — which `PageGeometry` normalizes back into a positive box
    /// the renderer draws bottom-left to top-right. Assumes points run left to right, x1 ≤ x2.
    static func lineSegment(id: String, x1: Double, y1: Double, x2: Double, y2: Double, weightPt: Double, color: ThemeColorType) -> PageElement {
        let w = abs(x2 - x1)
        let h = max(abs(y2 - y1), 1)
        let ascending = y2 < y1
        let originX = min(x1, x2)
        let originY = ascending ? max(y1, y2) : min(y1, y2)
        return PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: ascending ? -1 : 1, translateX: originX, translateY: originY, unit: .emu),
            line: Line(
                lineProperties: LineProperties(
                    lineFill: LineFill(solidFill: SolidFill(color: OpaqueColor(themeColor: color))),
                    weight: Dimension(magnitude: weightPt, unit: .pt)
                ),
                lineCategory: .straight
            )
        )
    }

    /// Formats a bar value for display: a whole number loses its decimal point, and the integer part
    /// gets thousands separators. 12.0 becomes "12", 1234.5 becomes "1,234.5".
    static func formatValue(_ value: Double) -> String {
        if value == value.rounded() { return groupDigits(String(Int(value))) }
        let s = String(value)
        guard let dot = s.firstIndex(of: ".") else { return groupDigits(s) }
        return groupDigits(String(s[..<dot])) + String(s[dot...])
    }

    /// Inserts thousands separators into a digit string, preserving a leading sign. Non-numeric input
    /// passes through untouched.
    static func groupDigits(_ s: String) -> String {
        var digits = s
        let sign = digits.hasPrefix("-") ? "-" : ""
        if !sign.isEmpty { digits.removeFirst() }
        guard digits.count > 3, digits.allSatisfy(\.isNumber) else { return s }
        var grouped = ""
        for (offset, ch) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        return sign + String(grouped.reversed())
    }

    /// The degraded form used when the body has no geometry: one bullet per bar, as "label: value".
    static func chartFallbackText(_ chart: SemanticChart) -> TextContent {
        TextContent(textElements: chart.bars.flatMap { bar in
            paragraphElements(
                marker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: bulletGlyph(for: 0))),
                runs: inlineRuns("\(bar.label): \(bar.caption ?? formatValue(bar.value))")
            )
        })
    }

    // MARK: - Process flow (native arrow-joined step cards — no image)

    /// Expands steps into a left-to-right row of arrow-joined cards.
    ///
    /// Each card is a subtly filled rounded rectangle holding the step label and an optional caption,
    /// with an accent arrow into the next. Cards share the width evenly, so a long flow produces
    /// narrow cards rather than wrapping to a second row.
    static func stepElements(slideId: String, bodyIndex: Int, rect: PlaceholderSpec, steps: [SemanticStep]) -> [PageElement] {
        let arrowGap = 420_000.0
        let cardW = (rect.w - arrowGap * Double(steps.count - 1)) / Double(steps.count)
        let cardH = min(rect.h * 0.62, 1_500_000)
        let cardY = rect.y + (rect.h - cardH) / 2
        let prefix = "\(slideId)-step-\(bodyIndex)"
        var elements: [PageElement] = []

        for (i, step) in steps.enumerated() {
            let cardX = rect.x + (cardW + arrowGap) * Double(i)
            elements.append(card(id: "\(prefix)-\(i)-card", x: cardX, y: cardY, w: cardW, h: cardH, color: .light2))

            let hasCaption = !(step.caption ?? "").isEmpty
            // Label: centered (full card) when alone, upper half when a caption follows.
            let labelSpec = PlaceholderSpec(
                x: cardX + 120_000, y: cardY, w: cardW - 240_000, h: hasCaption ? cardH * 0.56 : cardH,
                fontSizePt: 18, themeColor: .text1, bold: true, align: .center, vAlign: hasCaption ? .bottom : .middle
            )
            elements.append(textBox(id: "\(prefix)-\(i)-label", spec: labelSpec, text: plainText(step.label)))
            if hasCaption {
                let captionSpec = PlaceholderSpec(
                    x: cardX + 120_000, y: cardY + cardH * 0.56, w: cardW - 240_000, h: cardH * 0.44,
                    fontSizePt: 12, themeColor: .dark2, bold: false, align: .center, vAlign: .top
                )
                elements.append(textBox(id: "\(prefix)-\(i)-caption", spec: captionSpec, text: plainText(step.caption!)))
            }

            // Arrow into the next card.
            if i < steps.count - 1 {
                let fromX = cardX + cardW + 80_000
                let toX = cardX + cardW + arrowGap - 80_000
                elements.append(arrowRight(id: "\(prefix)-\(i)-arrow", x1: fromX, x2: toX, centerY: cardY + cardH / 2, height: 200_000, color: .accent1))
            }
        }
        return elements
    }

    /// A filled rounded-rectangle card, drawn by the renderer as a shape background fill.
    static func card(id: String, x: Double, y: Double, w: Double, h: Double, color: ThemeColorType) -> PageElement {
        PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: w, unit: .emu), height: Dimension(magnitude: h, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: x, translateY: y, unit: .emu),
            shape: Shape(
                shapeType: .roundRectangle,
                shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: color))))
            )
        )
    }

    /// A right-pointing arrow spanning the gap between two cards, as a filled `rightArrow` shape.
    ///
    /// A shape rather than a `Line` because a line draws its box's diagonal, which for a wide, flat
    /// connector is unreliable; the shape fills its box pointing right.
    static func arrowRight(id: String, x1: Double, x2: Double, centerY: Double, height: Double, color: ThemeColorType) -> PageElement {
        PageElement(
            objectId: id,
            size: Size(width: Dimension(magnitude: abs(x2 - x1), unit: .emu), height: Dimension(magnitude: height, unit: .emu)),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: min(x1, x2), translateY: centerY - height / 2, unit: .emu),
            shape: Shape(
                shapeType: .rightArrow,
                shapeProperties: ShapeProperties(shapeBackgroundFill: ShapeBackgroundFill(
                    solidFill: SolidFill(color: OpaqueColor(themeColor: color))))
            )
        )
    }

    /// The degraded form used when the body has no geometry: one bullet per step, as "label — caption".
    static func stepsFallbackText(_ steps: [SemanticStep]) -> TextContent {
        TextContent(textElements: steps.flatMap { step in
            let caption = step.caption.map { " — " + $0 } ?? ""
            return paragraphElements(
                marker: ParagraphMarker(bullet: Bullet(nestingLevel: 0, glyph: bulletGlyph(for: 0))),
                runs: inlineRuns("\(step.label)\(caption)")
            )
        })
    }

    // MARK: - Quote (testimonial / pull quote — decorative mark + quote + attribution)

    /// Expands a testimonial into a pull quote: an oversized accent quotation mark, the quote set
    /// large, and a muted right-aligned attribution line. Native text elements only.
    static func quoteElements(slideId: String, bodyIndex: Int, rect: PlaceholderSpec, quote: SemanticQuote) -> [PageElement] {
        let prefix = "\(slideId)-quote-\(bodyIndex)"
        var elements: [PageElement] = []

        // Oversized opening quotation mark, top-left.
        let markSpec = PlaceholderSpec(
            x: rect.x, y: rect.y, w: 900_000, h: 900_000,
            fontSizePt: 90, themeColor: .accent1, bold: true, align: .start, vAlign: .top
        )
        elements.append(textBox(id: "\(prefix)-mark", spec: markSpec, text: plainText("\u{201C}")))

        let hasAttribution = !(quote.author ?? "").isEmpty || !(quote.role ?? "").isEmpty
        let attrH = hasAttribution ? 500_000.0 : 0
        // Quote text — large, sits below the mark and above any attribution.
        let textSpec = PlaceholderSpec(
            x: rect.x + 120_000, y: rect.y + 620_000, w: rect.w - 120_000, h: max(rect.h - 620_000 - attrH, 1),
            fontSizePt: 26, themeColor: .text1, bold: false, align: .start, vAlign: .top
        )
        elements.append(textBox(id: "\(prefix)-text", spec: textSpec, text: plainText(quote.text)))

        if hasAttribution {
            let attrSpec = PlaceholderSpec(
                x: rect.x, y: rect.y + rect.h - attrH, w: rect.w, h: attrH,
                fontSizePt: 15, themeColor: .dark2, bold: false, align: .end, vAlign: .middle
            )
            elements.append(textBox(id: "\(prefix)-attr", spec: attrSpec, text: plainText(attributionText(quote))))
        }
        return elements
    }

    /// The attribution line, built from whichever of author and role are present. Empty when neither
    /// is, so the caller can omit the line entirely.
    static func attributionText(_ quote: SemanticQuote) -> String {
        let parts = [quote.author, quote.role].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "" : "— " + parts.joined(separator: "、")
    }

    /// The degraded form used when the body has no geometry: the quote and attribution as plain text.
    static func quoteFallbackText(_ quote: SemanticQuote) -> String {
        let attr = attributionText(quote)
        return attr.isEmpty ? "\u{201C}\(quote.text)\u{201D}" : "\u{201C}\(quote.text)\u{201D}\n\(attr)"
    }

    /// Applies the spec's default text style and alignment to runs and paragraphs that carry none.
    ///
    /// Only nil fields are filled, so inline emphasis — bold and accent runs — survives. Paragraph
    /// style is set only on elements that already open a paragraph; run-only elements stay runs, which
    /// is what keeps the renderer drawing them on the same line.
    static func styled(_ text: TextContent, with spec: PlaceholderSpec) -> TextContent {
        var text = text
        text.textElements = text.textElements?.map { element in
            var element = element
            if var run = element.textRun {
                var style = run.style ?? TextStyle()
                if style.fontSize == nil { style.fontSize = spec.defaultStyle.fontSize }
                if style.foregroundColor == nil { style.foregroundColor = spec.defaultStyle.foregroundColor }
                if style.bold == nil { style.bold = spec.bold }
                if style.fontFamily == nil { style.fontFamily = spec.defaultStyle.fontFamily }
                if style.weightedFontFamily == nil { style.weightedFontFamily = spec.defaultStyle.weightedFontFamily }
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

    /// The bullet glyph for a nesting level, giving a multi-level list visible hierarchy. The
    /// renderer indents by level as well.
    static func bulletGlyph(for level: Int) -> String {
        switch level {
        case 0: "•"   // a light mid-dot reads more professional than a heavy filled circle (reference decks prefer restrained markers)
        case 1: "◦"
        default: "▪"
        }
    }

    /// A body flattened to plain text for layout matching, bullets and table cells included, so a
    /// body carrying only a table still counts as content.
    static func bodyMatchText(_ body: SemanticBody) -> String {
        let bullets = (body.bullets ?? []).map(\.text).joined(separator: "\n")
        return [bullets, tableText(body.table)].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func tableText(_ table: SemanticTable?) -> String {
        guard let table else { return "" }
        let rows = (table.headers.map { [$0] } ?? []) + table.rows
        return rows.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    /// Builds a `Table` element from a semantic table, emphasizing the header row and padding rows of
    /// unequal length out to the widest one.
    ///
    /// - Parameter rect: Where to place it. Pass nil to emit no geometry, leaving the renderer to
    ///   flow it into the semantic layout.
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

    /// The elements of one paragraph.
    ///
    /// A marker opens it and carries the first run in compact form; further inline runs follow as
    /// run-only elements on the same line. A trailing newline marks the end of the paragraph.
    static func paragraphElements(marker: ParagraphMarker, runs: [TextRun]) -> [TextElement] {
        guard var last = runs.last else { return [TextElement(paragraphMarker: marker)] }
        var runs = runs
        last.content = (last.content ?? "") + "\n"
        runs[runs.count - 1] = last
        var elements = [TextElement(paragraphMarker: marker, textRun: runs[0])]
        elements.append(contentsOf: runs.dropFirst().map { TextElement(textRun: $0) })
        return elements
    }

    /// Converts lightweight inline markup into styled runs: `**bold**` becomes bold and `==accent==`
    /// becomes accent-colored emphasis.
    ///
    /// Plain spans get no style at all, so the placeholder's defaults fill them in. Markers do not
    /// nest, and an unclosed marker is left as literal text.
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
