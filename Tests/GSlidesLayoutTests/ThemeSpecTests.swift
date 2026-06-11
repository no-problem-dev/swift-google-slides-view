import Testing
import GSlidesSchema
@testable import GSlidesLayout

/// Conformance of the design-intent layer to the Slides API theme model. Grounded in
/// constraints-catalog.yaml `theme-color-scheme-editable` / `rgb-color-range`.
@Suite struct ThemeSpecTests {

    // MARK: presets are valid, settable color schemes

    @Test(arguments: [ThemeSpec.light, ThemeSpec.dark])
    func presetsAreCompleteEditableSchemes(spec: ThemeSpec) {
        let scheme = spec.colorScheme
        // All 12 editable slots bound, every color in 0..1.
        #expect(scheme.missingEditableSlots.isEmpty)
        #expect(scheme.outOfRangeSlots.isEmpty)
        #expect(scheme.isCompleteEditableScheme)
    }

    // MARK: the synthesized scheme mirrors a real presentations.get master (16 entries)

    @Test func colorSchemeHasAll16ThemeColorTypes() {
        let types = ThemeSpec.light.colorScheme.colors?.compactMap(\.type) ?? []
        // 12 editable + 4 aliases, in discovery enum order.
        #expect(types == [
            .dark1, .light1, .dark2, .light2,
            .accent1, .accent2, .accent3, .accent4, .accent5, .accent6,
            .hyperlink, .followedHyperlink,
            .text1, .background1, .text2, .background2,
        ])
    }

    @Test func aliasSlotsMirrorTheirConcreteCounterparts() {
        // The API derives TEXT1<-DARK1, BACKGROUND1<-LIGHT1, TEXT2<-DARK2, BACKGROUND2<-LIGHT2.
        let scheme = ThemeSpec.dark.colorScheme
        #expect(scheme.rgb(for: .text1) == scheme.rgb(for: .dark1))
        #expect(scheme.rgb(for: .background1) == scheme.rgb(for: .light1))
        #expect(scheme.rgb(for: .text2) == scheme.rgb(for: .dark2))
        #expect(scheme.rgb(for: .background2) == scheme.rgb(for: .light2))
    }

    @Test func editableColorsAreInCanonicalSlotOrder() {
        #expect(ThemeSpec.light.editableColors.map(\.0) == ThemeColorType.editableSlots)
    }

    // MARK: arbitrary design intent (e.g. "white-based, blue accent") bakes faithfully

    @Test func customThemeBakesIntoColorScheme() throws {
        let white = try #require(RgbColor(hex: "#FFFFFF"))
        let ink = try #require(RgbColor(hex: "#0B0E14"))
        let blue = try #require(RgbColor(hex: "#1A73E8"))
        var spec = ThemeSpec.light
        spec.light1 = white; spec.dark1 = ink; spec.accent1 = blue
        let scheme = spec.colorScheme
        #expect(scheme.rgb(for: .light1) == white)
        #expect(scheme.rgb(for: .background1) == white)   // alias follows light1
        #expect(scheme.rgb(for: .dark1) == ink)
        #expect(scheme.rgb(for: .accent1) == blue)
        #expect(scheme.isCompleteEditableScheme)
    }

    @Test func hexParsingMatchesZeroToOneRange() throws {
        let c = try #require(RgbColor(hex: "FF8000"))
        #expect(c.red == 1.0)
        #expect(abs((c.green ?? 0) - 128.0 / 255.0) < 1e-9)
        #expect(c.blue == 0.0)
        #expect(RgbColor(hex: "xyz") == nil)
        #expect(RgbColor(hex: "#FFF") == nil)             // must be 6 digits
    }

    // MARK: an out-of-range / incomplete scheme is detected (negative path)

    @Test func incompleteSchemeIsFlagged() {
        let scheme = ColorScheme(colors: [ThemeColorPair(type: .accent1, color: RgbColor(red: 0.5, green: 0.5, blue: 0.5))])
        #expect(!scheme.isCompleteEditableScheme)
        #expect(scheme.missingEditableSlots.contains { $0 == .dark1 })
    }

    @Test func outOfRangeColorIsFlagged() {
        var spec = ThemeSpec.light
        spec.accent1 = RgbColor(red: 1.5, green: 0, blue: 0)   // > 1.0
        #expect(spec.colorScheme.outOfRangeSlots.contains { $0 == .accent1 })
        #expect(!spec.colorScheme.isCompleteEditableScheme)
    }

    // MARK: master synthesis carries the scheme

    @Test func masterCarriesThemeSpecScheme() {
        let page = PresentationTemplate.master(theme: ThemeSpec.dark)
        #expect(page.pageType == .master)
        #expect(page.pageProperties?.colorScheme == ThemeSpec.dark.colorScheme)
    }

    @Test func masterUsesTheSpecScheme() {
        #expect(PresentationTemplate.master(theme: .light).pageProperties?.colorScheme == ThemeSpec.light.colorScheme)
        #expect(PresentationTemplate.master(theme: .dark).pageProperties?.colorScheme == ThemeSpec.dark.colorScheme)
    }
}
