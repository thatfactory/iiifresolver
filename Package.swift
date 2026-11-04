// swift-tools-version:6.4

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "IIIFResolver",
    platforms: [.iOS(.v26), .macOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)],
    products: [.library(name: "IIIFResolver", targets: ["IIIFResolver"])],
    dependencies: [
        .package(url: "https://github.com/thatfactory/applogger", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.8.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "IIIFResolver",
            dependencies: [
                .product(name: "AppLogger", package: "applogger"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ],
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(
            name: "IIIFResolverTests",
            dependencies: [
                "IIIFResolver",
                .product(name: "AppLogger", package: "applogger"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ],
            resources: [.copy("Mocks/Fixtures")],
            swiftSettings: strictSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
