import Foundation

/// Google's `update*` requests carry a `fields` mask (comma-separated dotted paths, or `*`) naming
/// exactly which fields of the patch to apply; a path present in the mask but absent in the patch
/// resets that field. We honor this generically by merging at the JSON-object level: any Codable
/// patch + base + mask → a new value. One implementation covers every update request (text style,
/// shape/​image/line properties, page properties…), so the reducer never hand-rolls per-field copies.
enum FieldMask {
    /// Merge `patch` into `base` for the paths named by `fields`. `*` (or a path list containing it)
    /// replaces wholesale. A masked path missing from `patch` is removed from the result (reset).
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
