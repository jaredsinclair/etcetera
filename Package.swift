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
            name: "Etcetera"
            // Uncomment to enable complete strict concurrency checking. In a
            // future update, it would be handy if this were scriptable in CI:
            // swiftSettings: [ .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]) ]
        ),
        .testTarget(
            name: "EtceteraTests",
            dependencies: [
                "Etcetera"
            ]
        ),
    ]
)
