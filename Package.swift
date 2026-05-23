// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "audio-selector",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "audio-selector", targets: ["SelectSoundCLI"])
    ],
    targets: [
        .target(name: "SelectSoundCore"),
        .executableTarget(
            name: "SelectSoundCLI",
            dependencies: ["SelectSoundCore"]
        ),
        .testTarget(
            name: "SelectSoundCoreTests",
            dependencies: ["SelectSoundCore"]
        )
    ]
)
