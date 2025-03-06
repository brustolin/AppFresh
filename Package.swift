// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppFresh",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .visionOS(.v1)],
    products: [
        .library(
            name: "AppFresh",
            targets: ["AppFresh"]),
    ],
    targets: [
        .target(
            name: "AppFresh"),

    ]
)
