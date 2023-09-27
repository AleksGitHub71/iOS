// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Accounts",
    platforms: [
        .macOS(.v10_15), .iOS(.v14)
    ],
    products: [
        .library(
            name: "Accounts",
            targets: ["Accounts"]),
        .library(
            name: "AccountsMock",
            targets: ["AccountsMock"])
    ],
    dependencies: [
        .package(path: "../../../Domain/MEGADomain"),
        .package(path: "../../MEGAPresentation"),
        .package(path: "../../../UI/MEGASwiftUI"),
        .package(path: "../../Repository/MEGASDKRepo"),
        .package(path: "../../../Infrastracture/MEGATest")
    ],
    targets: [
        .target(
            name: "Accounts",
            dependencies: ["MEGADomain",
                           "MEGAPresentation",
                           "MEGASwiftUI"]
        ),
        .target(
            name: "AccountsMock",
            dependencies: ["Accounts"]
        ),
        .testTarget(
            name: "AccountsTests",
            dependencies: ["Accounts",
                           "AccountsMock",
                           "MEGADomain",
                           "MEGAPresentation",
                           "MEGATest",
                           .product(name: "MEGADomainMock", package: "MEGADomain"),
                           .product(name: "MEGASDKRepoMock", package: "MEGASDKRepo")]
        )
    ]
)