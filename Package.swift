// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [.macOS(.v14), .iOS(.v16), .watchOS(.v10)],
    products: [
        .executable(name: "glance", targets: ["glance"]),
        .library(name: "GlanceCore", targets: ["GlanceCore"]),
    ],
    targets: [
        .target(name: "GlanceCore"),
        .executableTarget(
            name: "glance",
            dependencies: ["GlanceCore"]
        ),
        // Menu-bar GUI (AppKit). Runs via `swift run glance-bar` — no Xcode needed
        // for dev; Xcode/codesign only for a notarized .app bundle later.
        .executableTarget(
            name: "glance-bar",
            dependencies: ["GlanceCore"]
        ),
        // CLT-friendly verification: no XCTest dependency, runs as a plain binary.
        .executableTarget(
            name: "glance-selftest",
            dependencies: ["GlanceCore"]
        ),
        .testTarget(
            name: "GlanceCoreTests",
            dependencies: ["GlanceCore"]
        ),
    ]
)
