import Foundation

/// vendoring されたピン留め済み Google Slides API 仕様 — パッケージ全体の単一信頼情報源。
///
/// `slides-api-discovery-v1.json` は型と enum を含む機械可読 discovery document；
/// `constraints-catalog.yaml` は objectId 正規表現・アトミシティ・フィールドマスク・ページ境界など
/// 散文のみの制約を権威あるソースから逐語引用する。ビルドの再現性とバリデーションの一貫性を保証するため
/// 両ファイルはここに凍結される。どちらかがピン留めリビジョンと乖離すると `SpecProvenanceTests` が失敗する。
/// 詳細は `Resources/Spec/PROVENANCE.md` を参照。
public enum GSlidesSpec {
    /// このビルドがピン留めする discovery `revision`。`scripts/fetch-discovery.sh` を実行し
    /// `SpecProvenanceTests` と照合した後、人間が手動で更新する。
    public static let pinnedRevision = "20260601"

    public static var discoveryDocumentURL: URL {
        Bundle.module.url(forResource: "Spec/slides-api-discovery-v1", withExtension: "json")!
    }

    public static func discoveryDocument() throws -> Data {
        try Data(contentsOf: discoveryDocumentURL)
    }

    public static var constraintsCatalogURL: URL {
        Bundle.module.url(forResource: "Spec/constraints-catalog", withExtension: "yaml")!
    }

    public static func constraintsCatalog() throws -> String {
        String(decoding: try Data(contentsOf: constraintsCatalogURL), as: UTF8.self)
    }

    /// ユーザー指定のオブジェクト ID 規則 — discovery doc の `CreateShapeRequest.objectId`
    /// 散文から逐語引用（`constraints-catalog.yaml` id `object-id-format` 参照）。
    /// 凍結された散文とそれを強制するコードの橋渡しであり、バリデーターが規則を記憶から
    /// 再記述しないよう一箇所に保持する。`SpecProvenanceTests` が discovery doc に
    /// 完全一致する散文を保持しているか確認する。
    public enum ObjectId {
        public static let minLength = 5
        public static let maxLength = 50
        /// アンカー付き正規表現: 先頭 `[a-zA-Z0-9_]`、残り `[a-zA-Z0-9_:-]`、合計長 5〜50。
        public static let pattern = "^[a-zA-Z0-9_][a-zA-Z0-9_:-]{4,49}$"

        /// `id` が API 仕様のオブジェクト ID フォーマット（長さ＋文字セット）を満たすか。
        public static func isValid(_ id: String) -> Bool {
            guard id.count >= minLength, id.count <= maxLength else { return false }
            guard let first = id.first, first == "_" || first.isASCII && first.isLetter || first.isNumber
            else { return false }
            return id.allSatisfy { c in
                c == "_" || c == "-" || c == ":" || (c.isASCII && (c.isLetter || c.isNumber))
            }
        }
    }
}
