// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeTmuxLights",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ClaudeTmuxLights",
            path: "Sources/ClaudeTmuxLights",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
