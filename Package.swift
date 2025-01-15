// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FLC",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "FLC",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "CoreXLSX", package: "CoreXLSX")
            ],
            path: "FLC",
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content/Preview Assets.xcassets"),
                .process("Templates/HR_template.xlsx"),
                .process("Templates/TestStatus_template.xlsx"),
                .process("Templates/PackageStatus_template.xlsx"),
                .process("Templates/MigrationStatus_template.xlsx"),
                .process("Templates/AD_template.xlsx"),
                .process("Templates/Cluster_template.xlsx")
            ]
        ),
        .testTarget(
            name: "FLCTests",
            dependencies: ["FLC"],
            path: "FLCTests"
        )
    ]
) 