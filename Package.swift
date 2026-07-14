// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Flusso",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
        .package(url: "https://github.com/MrKai77/DynamicNotchKit.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "FlussoCore",
            path: "Sources/FlussoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Flusso",
            dependencies: [
                "FlussoCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit"),
            ],
            path: "Sources/Flusso",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FlussoChecks",
            dependencies: ["FlussoCore"],
            path: "Tests/FlussoChecks",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
