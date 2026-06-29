/// テーマカラー 1 種と具体 RGB の対応（マスターのカラースキームエントリー）。
public struct ThemeColorPair: Codable, Equatable, Sendable {
    public var type: ThemeColorType?
    public var color: RgbColor?

    public init(type: ThemeColorType? = nil, color: RgbColor? = nil) {
        self.type = type
        self.color = color
    }
}

/// プレゼンテーションのパレット：テーマカラー名 → RGB。ページプロパティ上に存在し、
/// master → layout → slide の順に継承される。`ACCENT1` を実際の色に解決するのはこれ。
public struct ColorScheme: Codable, Equatable, Sendable {
    public var colors: [ThemeColorPair]?

    public init(colors: [ThemeColorPair]? = nil) {
        self.colors = colors
    }

    /// このスキームにテーマカラーの RGB 束縛が存在すれば解決して返す。
    public func rgb(for themeColor: ThemeColorType) -> RgbColor? {
        colors?.first { $0.type == themeColor }?.color
    }

    /// このスキームで未束縛の編集可能スロット。API のカラースキーム更新には先頭 12 種のすべてが必要なため、
    /// 空でなければ更新できない。(catalog: theme-color-scheme-editable)
    public var missingEditableSlots: [ThemeColorType] {
        let bound = Set((colors ?? []).compactMap { $0.type?.rawValue })
        return ThemeColorType.editableSlots.filter { !bound.contains($0.rawValue) }
    }

    /// RGB 成分が仕様の 0.0〜1.0 範囲外の束縛スロットとそのスロット名。
    public var outOfRangeSlots: [ThemeColorType] {
        (colors ?? []).compactMap { pair in
            guard let type = pair.type, let color = pair.color, !color.componentsInRange else { return nil }
            return type
        }
    }

    /// このスキームが有効な設定可能カラースキームかどうか：12 種すべてが束縛済みかつ全成分が範囲内。
    public var isCompleteEditableScheme: Bool {
        missingEditableSlots.isEmpty && outOfRangeSlots.isEmpty
    }
}

public struct MasterProperties: Codable, Equatable, Sendable {
    public var displayName: String?

    public init(displayName: String? = nil) {
        self.displayName = displayName
    }
}

public struct NotesProperties: Codable, Equatable, Sendable {
    public var speakerNotesObjectId: String?

    public init(speakerNotesObjectId: String? = nil) {
        self.speakerNotesObjectId = speakerNotesObjectId
    }
}
