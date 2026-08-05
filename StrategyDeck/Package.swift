// swift-tools-version: 5.9
import PackageDescription

// Swift tools 5.9 keeps the package in Swift 5 language mode, which avoids the
// stricter Swift 6 concurrency diagnostics for this AppKit/SwiftUI utility.
let package = Package(
    name: "StrategyDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StrategyDeck", targets: ["StrategyDeck"]),
        .library(name: "StrategyDeckCore", targets: ["StrategyDeckCore"])
    ],
    targets: [
        // Pure, UI-free logic: models, persistence, filtering. Fully testable.
        .target(
            name: "StrategyDeckCore",
            path: "Sources/StrategyDeckCore"
        ),
        // The macOS app: window management, global shortcut, all SwiftUI views.
        .executableTarget(
            name: "StrategyDeck",
            dependencies: ["StrategyDeckCore"],
            path: "Sources/StrategyDeck"
        ),
        .testTarget(
            name: "StrategyDeckCoreTests",
            dependencies: ["StrategyDeckCore"],
            path: "Tests/StrategyDeckCoreTests"
        )
    ]
)
