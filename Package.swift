// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FLC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FLC", targets: ["FLC"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", branch: "master"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.19"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", exact: "0.14.2")
    ],
    targets: [
        .executableTarget(
            name: "FLC",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "ZIPFoundation",
                "CoreXLSX"
            ],
            path: "FLC"
        ),
        .testTarget(
            name: "FLCTests",
            dependencies: ["FLC"],
            path: "FLCTests"
        )
    ]
) 