// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnimePlayer",
    platforms: [.iOS(.v17)],
    products: [
        .iOSApplication(
            name: "AnimePlayer",
            targets: ["AnimePlayer"],
            bundleIdentifier: "com.animeplayer.app",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.phone, .pad],
            infoPlist: [
                "UIBackgroundModes": ["audio"],
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true
                ]
            ]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnimePlayer",
            dependencies: [],
            resources: []
        )
    ]
)
