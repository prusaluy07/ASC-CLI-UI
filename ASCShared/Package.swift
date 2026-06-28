// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ASCShared",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ASCShared", targets: ["ASCShared"])
    ],
    targets: [
        .target(
            name: "ASCShared",
            swiftSettings: [
                // Match the host app's Swift 5 language mode + approachable concurrency
                // defaults so the shared code compiles identically on both targets.
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "ASCSharedTests",
            dependencies: ["ASCShared"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
