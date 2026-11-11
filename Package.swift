// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Silhouette",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Silhouette", targets: ["Silhouette"]),
    ],
    targets: [
        .target(name: "Silhouette"),
        .testTarget(name: "SilhouetteTests", dependencies: ["Silhouette"]),
    ]
)
