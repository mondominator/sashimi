// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sashimi",
    platforms: [
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "Sashimi",
            targets: ["Sashimi"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "Sashimi",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Sashimi"
        ),
    ]
)
