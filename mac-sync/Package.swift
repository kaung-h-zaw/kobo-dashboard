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
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/KoboAppleSync/Info.plist",
                ]),
            ]
        ),
    ]
)
