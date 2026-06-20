// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "file_picker", path: "/Users/aschilken/.pub-cache/hosted/pub.dev/file_picker-8.3.7/ios/file_picker"),
        .package(name: "path_provider_foundation", path: "/Users/aschilken/.pub-cache/hosted/pub.dev/path_provider_foundation-2.4.2/darwin/path_provider_foundation"),
        .package(name: "sqlite3_flutter_libs", path: "/Users/aschilken/.pub-cache/hosted/pub.dev/sqlite3_flutter_libs-0.5.42/darwin/sqlite3_flutter_libs")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "sqlite3-flutter-libs", package: "sqlite3_flutter_libs")
            ]
        )
    ]
)
