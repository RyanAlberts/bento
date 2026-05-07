// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Bento",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bento", targets: ["Bento"]),
        // Named "bentocli" at SPM/build level to avoid colliding with "Bento" on
        // case-insensitive APFS volumes. The install scripts symlink it to
        // /usr/local/bin/bento so users still type `bento`.
        .executable(name: "bentocli", targets: ["BentoCLI"]),
    ],
    targets: [
        .executableTarget(
            name: "Bento",
            path: "Sources/Bento",
            exclude: ["Resources/Info.plist"],
            resources: []
        ),
        .executableTarget(
            name: "BentoCLI",
            path: "Sources/BentoCLI"
        ),
        // Test target deferred to v0.2 alongside an XCTest setup that requires Xcode.
        // Command Line Tools alone ships neither XCTest nor swift-testing.
    ]
)
