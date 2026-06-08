// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-google-slides-view",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Google Slides API presentation スキーマのプロファイル（セマンティック・サブセット）。
        // フィールド名・enum は本家 discovery document と同名（enum parity をテストで強制）。
        // UI 非依存 — CLI でテストが走る。
        .library(name: "GSlidesSchema", targets: ["GSlidesSchema"]),
        // コンテンツ → predefinedLayout の決定的マッチング（md2googleslides の rule 移植）と
        // placeholder 解決・EMU 座標計算。UI 非依存。
        .library(name: "GSlidesLayout", targets: ["GSlidesLayout"]),
        // (payload JSON, append, lastChunk) のチャンク列 → presentation 状態の純関数 reducer。
        // A2A の型には依存しない — プロトコルからの絶縁が責務。
        .library(name: "GSlidesAssembly", targets: ["GSlidesAssembly"]),
        // LLM 構造化出力スキーマと few-shot 例。LLM クライアントには依存しない（契約の提供のみ）。
        .library(name: "GSlidesPrompt", targets: ["GSlidesPrompt"]),
        // batchUpdate write モデル（46 Request/Response を含む Codable ミラー）。
        // 編集 API のリクエストを型安全に組み立てる。描画には不要。
        .library(name: "GSlidesRequests", targets: ["GSlidesRequests"]),
        // A2A 統合アダプタ: Artifact/DataPart ⇄ GSlidesSchema coding、
        // TaskArtifactUpdateEvent → GSlidesAssembly プリミティブの写像、metadata 語彙。
        // A2A 依存はこのターゲットだけに隔離する。
        .library(name: "GSlidesA2A", targets: ["GSlidesA2A"]),
        // SwiftUI レンダラ: 16:9 キャンバス + EMU→pt + placeholder 描画。
        // UI 依存は葉であるこのターゲットだけ（テストは Xcode 実行）。
        .library(name: "GSlidesRenderer", targets: ["GSlidesRenderer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.3.0"),
        .package(url: "https://github.com/no-problem-dev/swift-a2a.git", from: "0.5.0"),
        // レンダラのテーミング基盤: デッキの ColorScheme を DS ColorPalette に写し、
        // 中身もクロームも同じ @Environment(colorPalette) / Typography で描く。
        .package(url: "https://github.com/no-problem-dev/swift-design-system.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "GSlidesSchema",
            dependencies: [
                .product(name: "StructuredDataCore", package: "swift-structured-data"),
                .product(name: "JSONParsing", package: "swift-structured-data"),
            ],
            resources: [.copy("Resources/Spec")]
        ),
        .target(name: "GSlidesLayout", dependencies: ["GSlidesSchema"]),
        .target(name: "GSlidesAssembly", dependencies: ["GSlidesSchema"]),
        .target(name: "GSlidesPrompt", dependencies: ["GSlidesSchema", "GSlidesLayout"]),
        .target(name: "GSlidesRequests", dependencies: [
            "GSlidesSchema",
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
        .target(name: "GSlidesA2A", dependencies: [
            "GSlidesSchema",
            "GSlidesAssembly",
            .product(name: "A2ACore", package: "swift-a2a"),
        ]),
        .target(name: "GSlidesRenderer", dependencies: [
            "GSlidesSchema",
            "GSlidesLayout",
            .product(name: "DesignSystem", package: "swift-design-system"),
        ]),
        .testTarget(
            name: "GSlidesSchemaTests",
            dependencies: ["GSlidesSchema"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "GSlidesLayoutTests", dependencies: ["GSlidesLayout"]),
        .testTarget(name: "GSlidesAssemblyTests", dependencies: ["GSlidesAssembly"]),
        .testTarget(name: "GSlidesPromptTests", dependencies: ["GSlidesPrompt", "GSlidesLayout"]),
        .testTarget(name: "GSlidesRequestsTests", dependencies: ["GSlidesRequests"]),
        .testTarget(name: "GSlidesA2ATests", dependencies: ["GSlidesA2A"]),
        .testTarget(name: "GSlidesRendererTests", dependencies: ["GSlidesRenderer", "GSlidesPrompt"]),
    ]
)
