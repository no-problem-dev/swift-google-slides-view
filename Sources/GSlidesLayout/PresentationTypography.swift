/// デザイン入力としてのタイポグラフィ。セマンティックロールごとにフォントファミリー + 数値ウェイトで
/// 表現したタイプスケールで、`ThemeSpec` がカラーを適用するのと同じ方法でプレースホルダーの
/// デフォルトスタイルに適用する。語彙は Slides ネイティブ（`fontFamily` / ウェイト付きファミリー）を維持し、
/// ファミリー名は呼び出し元が供給する（汎用レンダラーは言語固有フォントをハードコードしない）。
/// `.system`（全ロール未設定）は従来のシステムフォント挙動を再現するため、安全なデフォルト。
public struct PresentationTypography: Sendable, Equatable {
    /// スライドの（レイアウト, プレースホルダータイプ）から導出するセマンティックタイポグラフィロール。
    /// タイプスケールがカラーとは独立してファミリー/ウェイトを割り当てる単位。
    public enum Role: Sendable, Hashable {
        /// コンテンツヘッドラインの上に置く小さなカテゴリキッカー。
        case eyebrow
        /// スライド/セクション/メインポイントの見出し。
        case title
        /// タイトルの下に置くサポートライン。
        case subtitle
        /// ボディコピー、箇条書き、キャプション。
        case body
        /// BIG_NUMBER スライドの大型メトリクス。
        case bigNumber
        /// ページ番号/フッタークロム。
        case footer
    }

    /// ロールが解決するファミリー + ウェイト。どちらのフィールドも nil の場合はプレースホルダーの
    /// デフォルト（システムフォント / レイアウトのデフォルトウェイト）に委ねる。部分的なスケールもきれいに合成できる。
    public struct RoleStyle: Sendable, Equatable {
        public var fontFamily: String?
        public var weight: Int?     // 数値フォントウェイト 100–900

        public init(fontFamily: String? = nil, weight: Int? = nil) {
            self.fontFamily = fontFamily
            self.weight = weight
        }
    }

    private var styles: [Role: RoleStyle]

    public init(_ styles: [Role: RoleStyle] = [:]) {
        self.styles = styles
    }

    /// ロールのスタイル。スケールが設定していない場合は空の `RoleStyle`（両方 nil）を返す。
    public func style(for role: Role) -> RoleStyle { styles[role] ?? RoleStyle() }

    /// タイポグラフィオーバーライドなし。プレースホルダーはシステムフォント + デフォルトウェイトを保持する（従来の挙動）。
    public static let system = PresentationTypography()
}
