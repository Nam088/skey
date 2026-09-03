// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SKey",
    defaultLocalization: "vi",
    platforms: [
        // Keep this compatible with the declared Swift tools version (5.9).
        // macOS 14 is also the deployment target used by the application build.
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SKey", targets: ["SKey"])
    ],
    targets: [
        .target(
            name: "CSKey",
            path: "Sources/CSKey",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "SKey",
            dependencies: ["CSKey"],
            path: "Sources",
            exclude: [
                "CSKey"
            ],
            resources: [
                .process("../Resources")
            ],
            cSettings: [
                .headerSearchPath("CSKey/include")
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header", "Support/BridgingHeader.h"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L../../../core/target/release",
                    "-lskey"
                ]),
                .linkedFramework("Cocoa"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CryptoKit"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "SKeyTests",
            dependencies: ["SKey"],
            path: "Tests/Unit"
        )
    ]
)
