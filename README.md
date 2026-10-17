# MojangAPI

OpenAPI of Mojang for Minecraft: [openapi.yaml](Sources/MojangAPI/openapi.yaml)

[![][swift]][repo] [![][platform]][repo]

## Usage

```swift
import PackageDescription
let package = Package(    
    dependencies: [
        .package(
            url: "https://github.com/OrzMC/MojangAPI.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "<Your Target Name>",
            dependencies: ["MojangAPI"]
        )
    ]
)
```

check the tests to learn usage of this api: [MojangAPITests](Tests/MojangAPITests/MojangAPITests.swift)

## Quick Start

```swift
import MojangAPI

// 可选：配置重试次数
Mojang.configureNetwork(retries: 1)

// 获取清单的传输对象摘要
let summary = ManifestSummary(fromManifest: try await Mojang.manifest())
let releases = summary.filter(type: .release)

// 直接获取最新版本信息（传输对象）
let latest = try await Mojang.latestInfo(type: .release)

// 按版本过滤（传输对象）
let versions = try await Mojang.versionsInfo(id: "1.21")

// 查询用户信息（传输对象）
let profile = try await Mojang.userProfile(with: "Notch")
```

[swift]: <https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOrzMC%2FMojangAPI%2Fbadge%3Ftype%3Dswift-versions>
[platform]: <https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOrzMC%2FMojangAPI%2Fbadge%3Ftype%3Dplatforms>
[repo]: <https://swiftpackageindex.com/OrzMC/MojangAPI>

## 说明

- 本库仅包含 Mojang 原生接口：版本清单、包信息与用户信息
- 统一错误类型：`requestFailed(status)` 与 `notFound`（404），解析扩展使用 `output.jsonOrThrow()`
- 并发安全缓存（actor）：缓存清单与按版本细粒度数据，含 LRU 逐出策略；清单 TTL 默认 1 小时
- 为适配上游包响应在部分版本中缺少 `client_mappings`/`server_mappings`，`Downloads` 必填字段仅保留 `client` 与 `server`

## API 一览

- Mojang.manifest(forceUpdate:)：获取清单（含 TTL 缓存）
- Mojang.latestInfo(type:forceUpdate:)：获取指定类型最新版本（传输对象）
- Mojang.versionsInfo(id:type:forceUpdate:)：按类型/关键字过滤版本（传输对象）
- Mojang.userProfile(with:)：按用户名查询用户资料（传输对象）
- Version.gameVersion：解析版本对应的包详情（GameVersion）
- GameVersion.assetIndexObject：解析资源索引对应对象列表（GameVersionAsset）
- Components.Schemas.Object.resourceURL：构造资源下载 URL

## 更多示例

```swift
// 获取最新 release 的包详情与资源索引对象
if let latest = try await Mojang.latestInfo(type: .release),
   let version = try await Mojang.versionsInfo(id: latest.id).first {
    // 通过生成类型 Version 的扩展解析包详情
    if let game = try await Components.Schemas.Version(id: version.id, _type: .release, url: version.url).gameVersion,
       let asset = try await game.assetIndexObject {
        // 遍历资源对象并构造下载 URL
        for (path, obj) in asset.objects {
            let url = obj.resourceURL
            print(path, url.absoluteString)
        }
    }
}
```

## 测试与 CI

- 包含离线解析与基础 API 测试，默认无需网络密钥即可运行
- GitHub Actions：.github/workflows/tests.yml（macos-latest），在 push/pull_request 自动构建与测试
