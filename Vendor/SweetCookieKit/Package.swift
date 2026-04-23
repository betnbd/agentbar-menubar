// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
let sweetCookieKitLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-l:libsqlite3.so.0"]),
]
#else
let sweetCookieKitLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("sqlite3"),
]
#endif

let package = Package(
    name: "SweetCookieKit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SweetCookieKit",
            targets: ["SweetCookieKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.5"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SweetCookieKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: sweetCookieKitLinkerSettings
        ),
        .testTarget(
            name: "SweetCookieKitTests",
            dependencies: ["SweetCookieKit"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
