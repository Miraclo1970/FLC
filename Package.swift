// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FLC",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.1"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "FLC",
            dependencies: [
                "CoreXLSX",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        )
    ]
) 