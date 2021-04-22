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
    dependencies: [
        .package(url: "https://github.com/teufelaudio/NetworkExtensions.git", .upToNextMajor(from: "0.1.6"))
    ],
    targets: [
        .target(name: "CombineLongPolling", dependencies: ["NetworkExtensions"])
    ]
)
