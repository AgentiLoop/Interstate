// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InterstateMapEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "InterstateMapEditor",
            targets: ["InterstateMapEditor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "InterstateMapEditor",
            path: ".",
            exclude: [
                "README.md",
                "Info.plist"
            ],
            sources: [
                "InterstateMapEditorApp.swift",
                "ContentView.swift",
                "DataManager.swift",
                "MapEditorView.swift"
            ]
        )
    ]
) 