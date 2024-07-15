// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "Etcetera",
    platforms: [
        .iOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "Etcetera", targets: ["Etcetera"])
    ],
    targets: [
        .target(
            name: "Etcetera",
            swiftSettings: [
                // Uncomment the following in local checkouts to enable strict
                // concurrency on demand. When Swift 6 supports lands in Fall
                // 2024, we will be able to remove the use of experimental
                // features altogether and specify the language mode instead.
                // .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EtceteraTests",
            dependencies: [
                "Etcetera"
            ]
        ),
    ]
)
