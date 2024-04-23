// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Search",
    platforms: [
        .macOS(.v10_15), .iOS(.v15)
    ],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]
        ),
        .library(
            name: "SearchMock",
            targets: ["SearchMock"]
        )
        
    ],
    dependencies: [
        .package(path: "../../../Infrastructure/MEGASwift"),
        .package(path: "../../../Localization/MEGAL10n"),
        .package(path: "../../../UI/MEGASwiftUI"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.1.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.12.0"
        ),
        .package(url: "https://github.com/meganz/MEGADesignToken", branch: "main")
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                "MEGASwiftUI",
                "MEGAL10n",
                "MEGASwift",
                "MEGADesignToken"
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .target(
            name: "SearchMock",
            dependencies: ["Search"],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search", 
                "SearchMock",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras")
            ],
            resources: [
                .process("folder.png"),
                .process("scenery.png")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        )
    ]
)
