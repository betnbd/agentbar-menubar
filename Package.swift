// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AgentBar",
    dependencies: [
        .package(path: "Vendor/Commander"),
        .package(url: "https://github.com/apple/swift-log", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.1"),
        .package(path: "Vendor/SweetCookieKit"),
    ],
    targets: {
        let targets: [Target] = [
            .systemLibrary(
                name: "CAgentBarTray",
                pkgConfig: "ayatana-appindicator3-0.1",
                providers: [
                    .apt([
                        "libayatana-appindicator3-dev",
                        "libgtk-3-dev",
                    ]),
                ]),
            .target(
                name: "CAgentBarTrayShim",
                dependencies: [
                    "CAgentBarTray",
                ],
                path: "Sources/CAgentBarTrayShim",
                publicHeadersPath: "include"),
            .target(
                name: "AgentBarCore",
                dependencies: [
                    "AgentBarMacroSupport",
                    .product(name: "Logging", package: "swift-log"),
                    .product(name: "SweetCookieKit", package: "SweetCookieKit"),
                ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .macro(
                name: "AgentBarMacros",
                dependencies: [
                    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                ]),
            .target(
                name: "AgentBarMacroSupport",
                dependencies: [
                    "AgentBarMacros",
                ]),
            .executableTarget(
                name: "AgentBarCLI",
                dependencies: [
                    "AgentBarCore",
                    .product(name: "Commander", package: "Commander"),
                ],
                path: "Sources/AgentBarCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AgentBar",
                dependencies: [
                    "AgentBarCore",
                    "CAgentBarTrayShim",
                ],
                path: "Sources/AgentBar",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .testTarget(
                name: "AgentBarTests",
                dependencies: ["AgentBarCore"],
                path: "Tests",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
        ]

        return targets
    }())
