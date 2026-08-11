/// A discovery-document enum mirrored as a string-backed Swift value.
///
/// Modeled as a `RawRepresentable` struct rather than a Swift enum so a value this profile does not
/// list still decodes and re-encodes unchanged instead of failing or collapsing to a default.
/// Tests enforce that `knownValues` is a subset of the pinned discovery document.
public protocol SpecEnum: RawRepresentable, Codable, Equatable, Sendable where RawValue == String {
    static var knownValues: [Self] { get }
}

public extension SpecEnum {
    /// Whether the pinned discovery document defines this value.
    ///
    /// Unknown values still decode, so this is false rather than an error. The edit validator uses it
    /// to reject, during local preflight, the enum values the API would refuse with HTTP 400.
    var isKnown: Bool { Self.knownValues.contains { $0.rawValue == rawValue } }
}
