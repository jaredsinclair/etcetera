// swift-tools-version:5.1

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
            name: "OSActivityShims"),
        .target(
            name: "Etcetera",
            dependencies: [
                "OSActivityShims"
            ]),
        .testTarget(name: "EtceteraTests",
            dependencies: [
                "Etcetera"
            ]),
    ]
)
