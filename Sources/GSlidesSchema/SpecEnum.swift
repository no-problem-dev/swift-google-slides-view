/// Slides API discovery document の enum を Swift でミラーした文字列 enum。
/// Swift enum ではなく `RawRepresentable` 構造体としてモデル化するため、
/// プロファイル外の値もロスレスで round-trip できる。`knownValues` ⊆ discovery はテストで強制される。
public protocol SpecEnum: RawRepresentable, Codable, Equatable, Sendable where RawValue == String {
    static var knownValues: [Self] { get }
}

public extension SpecEnum {
    /// この値が discovery document で定義済みかどうか。未知の値もロスレスでデコードされる（前方互換）が、
    /// 編集バリデーターはこれを使って HTTP 400 で弾かれる enum 値をローカル preflight でリジェクトする。
    var isKnown: Bool { Self.knownValues.contains { $0.rawValue == rawValue } }
}
