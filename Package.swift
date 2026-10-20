// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ReviveBAR",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ReviveBAR", targets: ["ReviveBAR"])
    ],
    targets: [
        .executableTarget(
            name: "ReviveBAR",
            path: "Sources/EssentialTouchBar"
        )
    ]
)
