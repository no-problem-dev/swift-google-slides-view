/// String enum mirroring an enum in the Slides API discovery document.
/// Modeled as RawRepresentable structs (not Swift enums) so that values outside
/// the profile round-trip losslessly; `knownValues` ⊆ discovery is enforced by tests.
public protocol SpecEnum: RawRepresentable, Codable, Equatable, Sendable where RawValue == String {
    static var knownValues: [Self] { get }
}
