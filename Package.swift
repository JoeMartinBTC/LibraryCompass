// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibraryCompass",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LibraryCompassCore",
            path: "Sources/LibraryCompassCore",
            swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]
        ),
        .executableTarget(
            name: "LibraryCompass",
            dependencies: ["LibraryCompassCore"],
            path: "Sources/LibraryCompass",
            swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]
        ),
        .testTarget(
            name: "LibraryCompassTests",
            dependencies: ["LibraryCompassCore"],
            path: "Tests/LibraryCompassTests",
            swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]
        )
    ]
)
