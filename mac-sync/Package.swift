// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KoboAppleSync",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KoboAppleSync", targets: ["KoboAppleSync"]),
    ],
    targets: [
        .executableTarget(
            name: "KoboAppleSync",
            exclude: ["Info.plist"]
        ),
    ]
)
