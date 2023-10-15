// swift-tools-version:5.8

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
            swiftSettings: [ .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]) ]
        ),
        .testTarget(
            name: "EtceteraTests",
            dependencies: [
                "Etcetera"
            ]
        ),
    ]
)
