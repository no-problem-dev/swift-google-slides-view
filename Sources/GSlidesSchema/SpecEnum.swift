/// String enum mirroring an enum in the Slides API discovery document.
/// Modeled as RawRepresentable structs (not Swift enums) so that values outside
/// the profile round-trip losslessly; `knownValues` ⊆ discovery is enforced by tests.
public protocol SpecEnum: RawRepresentable, Codable, Equatable, Sendable where RawValue == String {
    static var knownValues: [Self] { get }
}

public extension SpecEnum {
    /// Whether this value is one the discovery document defines. Values decode losslessly even when
    /// unknown (forward-compat), so the edit validator uses this to reject enum values the API
    /// would reject with HTTP 400 — turning a server round-trip into local, pre-flight feedback.
    var isKnown: Bool { Self.knownValues.contains { $0.rawValue == rawValue } }
}
