// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalDictation",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/argmaxinc/WhisperKit.git",
            exact: "0.13.0"
        )
    ],
    targets: [
        .target(
            name: "LocalDictationCore",
            path: "Sources/LocalDictationCore"
        ),
        .executableTarget(
            name: "LocalDictation",
            dependencies: [
                "LocalDictationCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/LocalDictation"
        ),
        .executableTarget(
            name: "LocalDictationSelfTest",
            dependencies: ["LocalDictationCore"],
            path: "Sources/LocalDictationSelfTest"
        )
    ]
)
