// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ActionBar",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "ActionBar",
            path: "Sources/ActionBar",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/ActionBar/Resources/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "ActionBarTests",
            dependencies: ["ActionBar"],
            path: "Tests/ActionBarTests"
        ),
    ]
)
