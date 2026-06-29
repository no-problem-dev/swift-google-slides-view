# ``GSlidesLayout``

Google Slides プレゼンテーションのジオメトリ、座標変換、レイアウトマッチング、スライドデザインシステム。

## Overview

GSlidesLayout は `GSlidesSchema`（ワイヤー型）と `GSlidesRenderer` / `GSlidesAssembly`（コンシューマー）の間に位置するデザインデータ層。このライブラリが扱う全計測値は Slides API のネイティブ単位である English Metric Unit (EMU) を使用する。``EMU`` は変換定数（1 インチ = 914,400 EMU、1 ポイント = 12,700 EMU）と標準 16:9 デフォルトページサイズを提供する。``PageGeometry`` は、API が全 `PageElement` に返す `size` + `transform` フィールドを読み取り、生の数値を `CGRect` / `CGSize` 値に変換する。

### レイアウトマッチング

``LayoutMatcher`` は セマンティックな ``SlideContent`` の記述（タイトル、サブタイトル、ボディ、テーブル数）を最適な `PredefinedLayout` にマッピングする。md2googleslides と同じルール順序を移植している。``PlaceholderResolver`` は Master → Layout → Slide の継承チェーンを辿り、レイアウト親に依存するスライド要素の欠損ジオメトリを補完する。

### テンプレートとデザインシステム

``PresentationTemplate`` はデッキ全体のデザインをデータとして表現する。マスターページ（``ThemeSpec`` カラースキームを持つ）と、各定義済みレイアウトのプレースホルダー矩形・デフォルトテキストスタイル（``PlaceholderSpec`` 値）がある。コンシューマーは `spec(layout:type:index:)` を呼び出してマジックナンバーを埋め込まずに完全設定済みのプレースホルダーを取得できる。

デザインシステム型 — ``SpacingScale``、``HeaderStyle``、``SlideDesignSystem`` — は垂直リズムトークンとヘッダー処理の選択をまとめ、1 つの値を変更するだけでデッキ全体の見た目を交換できるようにする。

``PresentationTypography`` は各セマンティックロール（タイトル、サブタイトル、ボディ、アイブロウ、ビッグナンバー、フッター）にフォントファミリーと数値ウェイトを割り当てる。``ThemeSpec`` がカラーを適用するのと同じ方法でジオメトリの上に重ねて適用し、`.system`（全ロール未設定）は常に安全なデフォルト。

```swift
import GSlidesLayout

// スライドに最適な定義済みレイアウトを推論する
let content = SlideContent(
    title: .init("Q3 Results"),
    bodies: [.init(text: .init("Revenue grew 42 % YoY"))]
)
let layout = LayoutMatcher.match(content)   // → .titleAndBody

// そのレイアウトのタイトルスロットのプレースホルダー spec を構築する
let spec = PresentationTemplate.spec(
    layout: layout,
    type: .title,
    index: 0,
    typography: .system
)
// spec?.size, spec?.transform — PageElement に埋め込む準備完了
```

## Topics

### 座標ユーティリティ

- ``EMU``
- ``PageGeometry``

### プレースホルダー解決

- ``PlaceholderResolver``
- ``PlaceholderSpec``
- ``PresentationTemplate``

### レイアウトマッチング

- ``SlideContent``
- ``LayoutMatcher``

### デザインシステム

- ``SlideDesignSystem``
- ``SpacingScale``
- ``HeaderStyle``

### カラーとタイポグラフィ

- ``ThemeSpec``
- ``PresentationTypography``
