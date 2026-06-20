// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "file_picker", path: "../.packages/file_picker"),
        .package(name: "sqlite3_flutter_libs", path: "../.packages/sqlite3_flutter_libs"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "sqlite3-flutter-libs", package: "sqlite3_flutter_libs"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation")
            ]
        )
    ]
)
