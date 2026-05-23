// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sound-selector",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "select-sound", targets: ["SelectSoundCLI"])
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
