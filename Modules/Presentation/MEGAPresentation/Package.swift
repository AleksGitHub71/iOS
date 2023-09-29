// swift-tools-version: 5.9

import PackageDescription

let settings: [SwiftSetting] = [.unsafeFlags(["-warnings-as-errors"]), .enableExperimentalFeature("ExistentialAny")]

let package = Package(
    name: "MEGAPresentation",
    platforms: [
        .macOS(.v10_15), .iOS(.v14)
    ],
    products: [
        .library(
            name: "MEGAPresentation",
            targets: ["MEGAPresentation"]
        ),
        .library(
            name: "MEGAPresentationMock",
            targets: ["MEGAPresentationMock"]
        )
    ],
    dependencies: [
        .package(path: "../../Domain/MEGADomain"),
        .package(path: "../../Domain/MEGAAnalyticsDomain"),
        .package(path: "../../Repository/MEGASDKRepo"),
        .package(path: "../../Infrastracture/MEGATest"),
        .package(url: "https://code.developers.mega.co.nz/mobile/kmm/mobile-analytics-ios.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MEGAPresentation",
            dependencies: [
                "MEGAAnalyticsDomain",
                "MEGADomain",
                "MEGASDKRepo",
                .product(name: "MEGAAnalyticsiOS", package: "mobile-analytics-ios")
            ],
            swiftSettings: settings),
        .target(
            name: "MEGAPresentationMock",
            dependencies: ["MEGAPresentation"]
        ),
        .testTarget(
            name: "MEGAPresentationTests",
            dependencies: ["MEGAPresentation",
                           "MEGAPresentationMock",
                           "MEGATest",
                           "MEGAAnalyticsDomain",
                           "MEGADomain",
                           "MEGASDKRepo",
                           .product(name: "MEGAAnalyticsiOS", package: "mobile-analytics-ios"),
                           .product(name: "MEGADomainMock", package: "MEGADomain")],
            swiftSettings: settings)
    ]
)
