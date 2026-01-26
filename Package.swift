// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PickleKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PickleKit", targets: ["PickleKit"]),
    ],
    targets: [
        .target(
            name: "PickleKit",
            dependencies: [],
            path: "Sources/PickleKit"
        ),
        .testTarget(
            name: "PickleKitTests",
            dependencies: ["PickleKit"],
            path: "Tests/PickleKitTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
