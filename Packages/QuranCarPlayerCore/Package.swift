// swift-tools-version:5.9
import PackageDescription

// Platform-independent domain, catalog, playback, and persistence logic.
// macOS is listed only so the package can be built and unit-tested with
// `swift test` on a development Mac without the iOS SDK. The app target is iOS.
let package = Package(
    name: "QuranCarPlayerCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QuranCarPlayerCore", targets: ["QuranCarPlayerCore"])
    ],
    targets: [
        .target(
            name: "QuranCarPlayerCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "QuranCarPlayerCoreTests",
            dependencies: ["QuranCarPlayerCore"]
        ),
    ]
)
