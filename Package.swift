// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineLongPolling",
    platforms: [
        .iOS(.v13), .tvOS(.v13), .macOS(.v10_15), .watchOS(.v6)
    ],
    products: [
        .library(name: "CombineLongPollingDynamic", type: .dynamic, targets: ["CombineLongPolling"]),
        .library(name: "CombineLongPolling", targets: ["CombineLongPolling"])
    ],
    dependencies: [],
    targets: [
        .target(name: "CombineLongPolling", dependencies: []),
        .testTarget(name: "CombineLongPollingTests", dependencies: ["CombineLongPolling"])
    ]
)
