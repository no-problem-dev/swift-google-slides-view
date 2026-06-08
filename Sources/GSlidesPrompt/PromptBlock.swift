import Foundation

/// Schema + worked example composed into a system-instruction block — the slide-deck
/// counterpart of A2UI's `SendA2UIToClientTool.systemInstruction` (pruned schema + reference
/// surface). The package owns this composition (and pins the example to the schema with tests)
/// so hosts attach one block instead of hand-rolling the prompt.
extension GSlidesGenerationContract {
    /// A canonical, schema-valid deck used as the few-shot example. Language-neutral on purpose —
    /// it teaches structure (layout choice, concise bullets, a big number, two columns); the host's
    /// role prompt handles localization. Pinned schema-valid by `exampleValidatesAgainstSchema`.
    public static let exampleDeckJSON = """
    {
      "title": "Quarterly Product Review",
      "slides": [
        { "layout": "TITLE", "title": "Quarterly Product Review", "subtitle": "Q2 highlights and what comes next" },
        { "title": "Three themes this quarter", "bodies": [ { "bullets": ["Faster onboarding", "Deeper integrations", "Higher reliability"] } ] },
        { "layout": "BIG_NUMBER", "title": "98.9%", "big": true, "bodies": [ { "text": "uptime across every region" } ] },
        { "layout": "TITLE_AND_TWO_COLUMNS", "title": "Before / after", "bodies": [ { "bullets": ["Manual setup", "Three days to launch"] }, { "bullets": ["One-click setup", "Same-day launch"] } ] }
      ]
    }
    """

    /// The example decoded — for tests and hosts that want the typed value.
    public static func exampleDeck() throws -> SemanticDeck {
        try validate(Data(exampleDeckJSON.utf8))
    }

    /// The system-instruction block: schema (what's allowed) + example (the quality bar).
    /// Faithful to A2UI's pattern — schema then a worked example the model should match in
    /// structure, not copy verbatim.
    public static func promptBlock() -> String {
        let schema = (try? jsonSchemaData()).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return """
        ### SLIDE DECK SCHEMA:
        The `deck_json` argument MUST validate against this JSON Schema:
        \(schema)

        ### EXAMPLE (match its structure and concision, not its content):
        \(exampleDeckJSON)
        """
    }
}
