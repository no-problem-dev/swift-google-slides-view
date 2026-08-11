import Foundation

/// Applies a Google `fields` mask — comma-separated dotted paths, or `*` — when merging an update
/// patch into an existing value.
///
/// A path listed in the mask but absent from the patch resets that field rather than leaving it
/// alone, which is the part callers get wrong. Implemented once at the JSON-object level so every
/// `update*` request — text style, shape, image, line, page properties — shares it and the reducer
/// never hand-copies fields.
enum FieldMask {
    /// Merges `patch` into `base` for the paths named in `fields`.
    ///
    /// A `*` anywhere in the list replaces the whole value with the patch. A path in the mask that
    /// the patch does not set is removed from the result. An empty mask is inferred from the patch's
    /// own top-level keys, so an agent that omits `fields` gets exactly the attributes it set.
    ///
    /// - Throws: The encoding or decoding error if the patch, the base, or the merged object cannot
    ///   round-trip through JSON.
    static func merge<T: Codable>(base: T?, patch: T, fields: String, as type: T.Type = T.self) throws -> T {
        let listed = fields
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if listed.contains("*") { return patch }

        let source = try object(of: patch) ?? [:]
        // Empty mask → infer it from the patch's present top-level keys, so an agent can omit
        // `fields` and have exactly the attributes it set applied (the intuitive update semantics).
        let paths = listed.isEmpty ? Array(source.keys) : listed
        if paths.isEmpty { return patch }

        var target = try object(of: base) ?? [:]
        for path in paths {
            let comps = path.split(separator: ".").map(String.init)
            if let value = lookup(source, comps) {
                assign(&target, comps, value)
            } else {
                remove(&target, comps)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: target)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func object<T: Encodable>(of value: T?) throws -> [String: Any]? {
        guard let value else { return nil }
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func lookup(_ dict: [String: Any], _ comps: [String]) -> Any? {
        guard let head = comps.first else { return nil }
        guard let value = dict[head] else { return nil }
        if comps.count == 1 { return value }
        guard let nested = value as? [String: Any] else { return nil }
        return lookup(nested, Array(comps.dropFirst()))
    }

    private static func assign(_ dict: inout [String: Any], _ comps: [String], _ value: Any) {
        let head = comps[0]
        if comps.count == 1 { dict[head] = value; return }
        var nested = dict[head] as? [String: Any] ?? [:]
        assign(&nested, Array(comps.dropFirst()), value)
        dict[head] = nested
    }

    private static func remove(_ dict: inout [String: Any], _ comps: [String]) {
        let head = comps[0]
        if comps.count == 1 { dict[head] = nil; return }
        guard var nested = dict[head] as? [String: Any] else { return }
        remove(&nested, Array(comps.dropFirst()))
        dict[head] = nested
    }
}
