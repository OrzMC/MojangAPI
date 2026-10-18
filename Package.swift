// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MojangAPI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "MojangAPI",
            targets: ["MojangAPI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-openapi-generator.git",
            from: "1.10.3"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-runtime.git",
            from: "1.9.0"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-urlsession.git",
            from: "1.2.0"
        ),
        .package(
            url: "https://github.com/OrzGeeker/OrzSwiftKit.git",
            branch: "main"
        ),
        // 非 Apple 平台没有 CryptoKit，用 swift-crypto 顶 `Insecure.SHA1`（决策 D8：跨平台）。
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "3.12.3"
        ),
    ],
    targets: [
        .target(
            name: "MojangAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
                .product(
                    name: "OpenAPIURLSession",
                    package: "swift-openapi-urlsession"
                ),
                .product(
                    name: "CacheKit",
                    package: "OrzSwiftKit"
                ),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
            ],
            plugins: [
                .plugin(
                    name: "OpenAPIGenerator",
                    package: "swift-openapi-generator"
                )
            ]
        ),
        .testTarget(
            name: "MojangAPITests",
            dependencies: ["MojangAPI", .product(name: "CacheKit", package: "OrzSwiftKit")],
            resources: [
                .process("Fixtures")
            ]
        ),
    ]
)
