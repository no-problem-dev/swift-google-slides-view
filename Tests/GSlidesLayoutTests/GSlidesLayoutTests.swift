import CoreGraphics
import Testing
import GSlidesSchema
@testable import GSlidesLayout

/// Port of md2googleslides test/match_layout.spec.ts — same inputs must
/// resolve to the same predefined layout names.
@Suite struct LayoutMatcherTests {
    @Test func title() {
        let slide = SlideContent(title: .init("title"), subtitle: .init("subtitle"))
        #expect(LayoutMatcher.match(slide) == .title)
    }

    @Test func sectionHeader() {
        let slide = SlideContent(title: .init("title"))
        #expect(LayoutMatcher.match(slide) == .sectionHeader)
    }

    @Test func mainPoint() {
        let slide = SlideContent(title: .init("title", big: true))
        #expect(LayoutMatcher.match(slide) == .mainPoint)
    }

    @Test func sectionTitleAndDescription() {
        let slide = SlideContent(
            title: .init("title"),
            subtitle: .init("subtitle"),
            bodies: [.init(text: .init("body"))]
        )
        #expect(LayoutMatcher.match(slide) == .sectionTitleAndDescription)
    }

    @Test func bigNumber() {
        let slide = SlideContent(
            title: .init("title", big: true),
            bodies: [.init(text: .init("body"))]
        )
        #expect(LayoutMatcher.match(slide) == .bigNumber)
    }

    @Test func titleAndTwoColumns() {
        let slide = SlideContent(
            title: .init("title"),
            bodies: [.init(text: .init("column1")), .init(text: .init("column2"))]
        )
        #expect(LayoutMatcher.match(slide) == .titleAndTwoColumns)
    }

    @Test func titleAndBody() {
        let slide = SlideContent(title: .init("title"), bodies: [.init(text: .init("body"))])
        #expect(LayoutMatcher.match(slide) == .titleAndBody)
    }

    @Test func titleAndBodyWithImageOnlyBody() {
        let slide = SlideContent(
            title: .init("title"),
            bodies: [.init(text: .init(""), imageCount: 1)]
        )
        #expect(LayoutMatcher.match(slide) == .titleAndBody)
    }

    @Test func titleAndBodyWithBodyOnly() {
        let slide = SlideContent(bodies: [.init(text: .init("body"))])
        #expect(LayoutMatcher.match(slide) == .titleAndBody)
    }

    @Test func blank() {
        #expect(LayoutMatcher.match(SlideContent()) == .blank)
    }

    @Test func tableOnlySlideIsNotSectionHeader() {
        let slide = SlideContent(title: .init("title"), tableCount: 1)
        #expect(LayoutMatcher.match(slide) == .titleAndBody)
    }

    @Test func customLayoutResolvesToLayoutId() {
        let layout = Page(
            objectId: "layout-1",
            pageType: .layout,
            layoutProperties: LayoutProperties(name: "TITLE", displayName: "My Custom")
        )
        let presentation = Presentation(layouts: [layout])
        let slide = SlideContent(title: .init("title"), customLayout: "My Custom")
        let reference = LayoutMatcher.reference(for: slide, in: presentation)
        #expect(reference.layoutId == "layout-1")
        #expect(reference.predefinedLayout == nil)
    }

    @Test func unknownCustomLayoutFallsBackToRules() {
        let slide = SlideContent(title: .init("title"), customLayout: "Nope")
        let reference = LayoutMatcher.reference(for: slide, in: Presentation())
        #expect(reference.predefinedLayout == .sectionHeader)
    }
}

@Suite struct GeometryTests {
    @Test func pointConversion() {
        let dimension = Dimension(magnitude: 18, unit: .pt)
        #expect(dimension.emuMagnitude == 228_600.0)
        #expect(dimension.pointMagnitude == 18.0)
    }

    @Test func emuPassesThrough() {
        let dimension = Dimension(magnitude: 914_400, unit: .emu)
        #expect(dimension.emuMagnitude == 914_400)
    }

    @Test func elementFrameAppliesTransform() {
        let element = PageElement(
            objectId: "e",
            size: Size(
                width: Dimension(magnitude: 3_000_000, unit: .emu),
                height: Dimension(magnitude: 1_000_000, unit: .emu)
            ),
            transform: AffineTransform(
                scaleX: 2, scaleY: 1,
                translateX: 311_700, translateY: 445_025,
                unit: .emu
            )
        )
        let frame = PageGeometry.frame(of: element)
        #expect(frame == CGRect(x: 311_700, y: 445_025, width: 6_000_000, height: 1_000_000))
    }

    @Test func defaultPageSizeIs16x9() {
        let size = PageGeometry.pageSize(of: Presentation())
        let ratio = size.width / size.height
        #expect(abs(ratio - 16.0 / 9.0) < 0.0001)
    }

    /// A negative scale (a flip) normalizes to a positive rect with the origin moved to the top-left,
    /// so a vertically-flipped line element still occupies the intended box.
    @Test func negativeScaleNormalizesToPositiveRect() {
        let element = PageElement(
            objectId: "e",
            size: Size(
                width: Dimension(magnitude: 2_000_000, unit: .emu),
                height: Dimension(magnitude: 1_000_000, unit: .emu)
            ),
            transform: AffineTransform(
                scaleX: 1, scaleY: -1,
                translateX: 500_000, translateY: 3_000_000,
                unit: .emu
            )
        )
        // scaleY -1 anchored at y=3_000_000 → box spans [2_000_000, 3_000_000], positive height.
        #expect(PageGeometry.frame(of: element) == CGRect(x: 500_000, y: 2_000_000, width: 2_000_000, height: 1_000_000))
    }
}

@Suite struct PlaceholderResolverTests {
    static func presentation() -> Presentation {
        let layoutElement = PageElement(
            objectId: "layout-title-element",
            size: Size(
                width: Dimension(magnitude: 8_000_000, unit: .emu),
                height: Dimension(magnitude: 1_000_000, unit: .emu)
            ),
            transform: AffineTransform(scaleX: 1, scaleY: 1, translateX: 100, translateY: 200, unit: .emu),
            shape: Shape(placeholder: Placeholder(type: .title))
        )
        let layout = Page(objectId: "layout-1", pageType: .layout, pageElements: [layoutElement])
        let slideElement = PageElement(
            objectId: "slide-title-element",
            shape: Shape(
                text: TextContent(textElements: [TextElement(textRun: TextRun(content: "Hello"))]),
                placeholder: Placeholder(type: .title, parentObjectId: "layout-title-element")
            )
        )
        let slide = Page(
            objectId: "slide-1",
            pageElements: [slideElement],
            slideProperties: SlideProperties(layoutObjectId: "layout-1")
        )
        return Presentation(slides: [slide], layouts: [layout])
    }

    @Test func geometryInheritsFromLayoutByParentId() throws {
        let presentation = Self.presentation()
        let slide = try #require(presentation.slides?.first)
        let resolved = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
        let element = try #require(resolved.first)
        #expect(element.size?.width?.magnitude == 8_000_000)
        #expect(element.transform?.translateY == 200)
        #expect(element.shape?.text != nil)
    }

    @Test func geometryInheritsByTypeWhenNoParentId() throws {
        var presentation = Self.presentation()
        presentation.slides?[0].pageElements?[0].shape?.placeholder?.parentObjectId = nil
        let slide = try #require(presentation.slides?.first)
        let resolved = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
        #expect(resolved.first?.size?.width?.magnitude == 8_000_000)
    }

    @Test func explicitGeometryIsNotOverridden() throws {
        var presentation = Self.presentation()
        let ownSize = Size(width: Dimension(magnitude: 1, unit: .emu), height: Dimension(magnitude: 2, unit: .emu))
        presentation.slides?[0].pageElements?[0].size = ownSize
        presentation.slides?[0].pageElements?[0].transform = AffineTransform(scaleX: 1, scaleY: 1, unit: .emu)
        let slide = try #require(presentation.slides?.first)
        let resolved = PlaceholderResolver.resolvedElements(of: slide, in: presentation)
        #expect(resolved.first?.size == ownSize)
    }
}
