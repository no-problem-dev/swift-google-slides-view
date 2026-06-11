import Foundation
import Testing
import GSlidesSchema
import GSlidesLayout
@testable import GSlidesPrompt

/// The authoritative theme tool: inject the exact ColorScheme schema, parse the model's output, and
/// enforce the spec rules (all 12 editable slots, 0.0–1.0 components). No invented vocabulary.
@Suite struct ThemeContractTests {

    func scheme(_ pairs: [(ThemeColorType, RgbColor)]) -> Data {
        try! JSONEncoder().encode(ColorScheme(colors: pairs.map { ThemeColorPair(type: $0.0, color: $0.1) }))
    }
    var twelve: [(ThemeColorType, RgbColor)] { ThemeSpec.light.editableColors }

    // MARK: schema + prompt inject the authoritative shape

    @Test func schemaListsExactlyThe12EditableSlots() throws {
        let text = String(decoding: try GSlidesThemeContract.jsonSchemaData(), as: UTF8.self)
        for slot in ThemeColorType.editableSlots { #expect(text.contains(slot.rawValue)) }
        // the 4 read-only aliases must NOT be offered
        #expect(!text.contains("BACKGROUND1"))
        #expect(!text.contains("TEXT1"))
        #expect(!text.contains("THEME_COLOR_TYPE_UNSPECIFIED"))
    }

    @Test func promptBlockCarriesRulesSchemaAndExample() {
        let block = GSlidesThemeContract.promptBlock()
        #expect(block.contains("THEME RULES"))
        #expect(block.contains("0.0 to 1.0"))
        #expect(block.contains("THEME SCHEMA"))
        #expect(block.contains("THEME EXAMPLE"))
        #expect(block.contains("ACCENT1"))
    }

    // MARK: accept a complete, in-range scheme

    @Test func validatesCompleteScheme() throws {
        let out = try GSlidesThemeContract.validate(scheme(twelve))
        #expect(out.missingEditableSlots.isEmpty)
        #expect(out.colors?.count == 12)
    }

    @Test func workedExampleIsItselfValid() throws {
        // The example we teach the model must pass our own validator.
        let out = try GSlidesThemeContract.validate(Data(GSlidesThemeContract.workedExample().utf8))
        #expect(out.isCompleteEditableScheme)
    }

    // MARK: reject malformed / non-conforming output (with structured reasons)

    @Test func rejectsMissingSlot() {
        let eleven = Array(twelve.dropLast())   // drops FOLLOWED_HYPERLINK
        #expect(throws: GSlidesThemeContractError.self) {
            try GSlidesThemeContract.validate(scheme(eleven))
        }
        do { _ = try GSlidesThemeContract.validate(scheme(eleven)) }
        catch let GSlidesThemeContractError.missingSlots(slots) { #expect(slots.contains { $0 == .followedHyperlink }) }
        catch { Issue.record("wrong error: \(error)") }
    }

    @Test func rejectsOutOfRange() {
        var pairs = twelve
        pairs[4] = (.accent1, RgbColor(red: 1.5, green: 0, blue: 0))   // > 1.0
        do { _ = try GSlidesThemeContract.validate(scheme(pairs)); Issue.record("should throw") }
        catch let GSlidesThemeContractError.outOfRange(slots) { #expect(slots.contains { $0 == .accent1 }) }
        catch { Issue.record("wrong error: \(error)") }
    }

    @Test func rejectsUnknownType() {
        // Replace ACCENT6 with a non-existent ACCENT7 in the wire JSON.
        let json = GSlidesThemeContract.workedExample().replacingOccurrences(of: "ACCENT6", with: "ACCENT7")
        do { _ = try GSlidesThemeContract.validate(Data(json.utf8)); Issue.record("should throw") }
        catch let GSlidesThemeContractError.unknownTypes(types) { #expect(types.contains("ACCENT7")) }
        catch { Issue.record("wrong error: \(error)") }
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: GSlidesThemeContractError.self) {
            try GSlidesThemeContract.validate(Data("not json".utf8))
        }
    }

    // MARK: end-to-end — validated scheme bakes into a master

    @Test func themeSpecFromBakesIntoMaster() throws {
        let blue = try #require(RgbColor(hex: "#1A73E8"))
        // a white-canvas / blue-accent design intent
        var spec = ThemeSpec.light
        spec.light1 = try #require(RgbColor(hex: "#FFFFFF"))
        spec.accent1 = blue
        let data = scheme(spec.editableColors)

        let parsed = try GSlidesThemeContract.themeSpec(from: data)
        #expect(parsed == spec)

        let presentation = PresentationExpander.expand(
            SemanticPresentation(title: "t", slides: [SemanticSlide(title: "A")]), themeSpec: parsed)
        let masterScheme = presentation.masters?.first?.pageProperties?.colorScheme
        #expect(masterScheme?.rgb(for: .accent1) == blue)
        #expect(masterScheme?.rgb(for: .light1) == spec.light1)
        #expect(masterScheme == spec.colorScheme)
    }

    @Test func feedbackIsHumanReadableForEachError() {
        #expect(!GSlidesThemeContract.feedback(for: .missingSlots([.dark1])).isEmpty)
        #expect(GSlidesThemeContract.feedback(for: .outOfRange([.accent1])).contains("0.0 and 1.0"))
        #expect(GSlidesThemeContract.feedback(for: .unknownTypes(["ACCENT7"])).contains("ACCENT7"))
    }
}
