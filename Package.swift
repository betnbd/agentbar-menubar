// swift-tools-version: 6.2
import Foundation
import CompilerPluginSupport
import PackageDescription

func agentBarCommandSucceeds(_ arguments: [String]) -> Bool {
    #if os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    #else
        false
    #endif
}

let traySupportAvailable = agentBarCommandSucceeds([
    "pkg-config",
    "--exists",
    "ayatana-appindicator3-0.1",
    "gtk+-3.0",
])

let trayOnlySources = [
    "GNOMETrayHost.swift",
    "UsagePanelController.swift",
]

let package = Package(
    name: "AgentBar",
    dependencies: [
        .package(path: "Vendor/Commander"),
        .package(url: "https://github.com/apple/swift-log", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.1"),
        .package(path: "Vendor/SweetCookieKit"),
    ],
    targets: {
        var targets: [Target] = []

        if traySupportAvailable {
            targets += [
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
            ]
        }

        targets += [
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
                dependencies: ([
                    "AgentBarCore",
                ] + (traySupportAvailable ? ["CAgentBarTrayShim"] : [])),
                path: "Sources/AgentBar",
                exclude: traySupportAvailable ? [] : trayOnlySources,
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
