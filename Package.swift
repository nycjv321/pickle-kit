// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CucumberAndApples",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "CucumberAndApples", targets: ["CucumberAndApples"]),
    ],
    targets: [
        .target(
            name: "CucumberAndApples",
            dependencies: [],
            path: "Sources/CucumberAndApples"
        ),
        .testTarget(
            name: "CucumberAndApplesTests",
            dependencies: ["CucumberAndApples"],
            path: "Tests/CucumberAndApplesTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
