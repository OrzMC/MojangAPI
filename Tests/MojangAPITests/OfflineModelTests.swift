import Testing
import Foundation
@testable import MojangAPI

@Test
func decodeManifestSummaryFromFixtureFile() throws {
    guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let data = try Data(contentsOf: url)
    let summary = try JSONDecoder().decode(ManifestSummary.self, from: data)
    #expect(!summary.latestRelease.isEmpty)
    #expect(!summary.latestSnapshot.isEmpty)
    #expect(!summary.versions.isEmpty)
    #expect(summary.versions.first?.type == .release || summary.versions.first?.type == .snapshot)
}

@Test
func decodeUserProfileFromFixtureFile() throws {
    guard let url = Bundle.module.url(forResource: "user_notch", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let data = try Data(contentsOf: url)
    let profile = try JSONDecoder().decode(UserProfile.self, from: data)
    #expect(profile.name == "Notch")
    #expect(profile.id == "069a79f444e94726a5befca90e38aaf5")
}

@Test
func buildKindChannelNormalization() {
    #expect(BuildKind.release.channel == .release)
    #expect(BuildKind.snapshot.channel == .snapshot)
    // 非 release 一律归 snapshot
    #expect(BuildKind.oldBeta.channel == .snapshot)
    #expect(BuildKind.oldAlpha.channel == .snapshot)
}

@Test
func resolveChannelFromRealManifestFixture() throws {
    guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let summary = try JSONDecoder().decode(ManifestSummary.self, from: Data(contentsOf: url))
    let release = try #require(summary.resolve(.release))
    #expect(release.id == "1.21.1")
    #expect(release.type == .release)
    let snapshot = try #require(summary.resolve(.snapshot))
    #expect(snapshot.id == "24w45a")
    #expect(snapshot.type == .snapshot)
}

@Test
func javaRequirementReadsMajorVersion() throws {
    let data = Data(#"{"javaVersion":{"component":"java-runtime-gamma","majorVersion":17}}"#.utf8)
    let requirement = try Mojang.javaRequirement(fromVersionJSON: data)
    #expect(requirement.majorVersion == 17)
    #expect(requirement.distribution == "temurin")
    #expect(requirement.runtimeKind == "jre")
}

@Test
func javaRequirementDefaultsToEight() throws {
    let requirement = try Mojang.javaRequirement(fromVersionJSON: Data("{}".utf8))
    #expect(requirement.majorVersion == JavaRequirement.defaultMajor)
}

/// 最小可用版本 JSON（覆盖 `openapi.yaml` 的必填字段），用于磁盘缓存解码测试。
private let minimalVersionJSON = #"""
{
  "arguments": { "game": [], "jvm": [] },
  "assetIndex": { "id": "5", "totalSize": 0, "sha1": "0000000000000000000000000000000000000005", "size": 0, "url": "https://example/5.json" },
  "libraries": [],
  "downloads": {
    "client": { "sha1": "000000000000000000000000000000000000000c", "size": 0, "url": "https://example/client.jar" },
    "server": { "sha1": "0000000000000000000000000000000000000005", "size": 0, "url": "https://example/server.jar" }
  },
  "mainClass": "net.minecraft.client.main.Main",
  "id": "1.20.4",
  "type": "release",
  "time": "2024-01-01T00:00:00+00:00",
  "releaseTime": "2024-01-01T00:00:00+00:00",
  "minimumLauncherVersion": 21,
  "logging": { "client": { "argument": "-Dlog4j.configurationFile=${path}", "file": { "id": "client-1.12.xml", "sha1": "abc", "size": 0, "url": "https://example/log.xml" }, "type": "log4j2-xml" } }
}
"""#

@Test
func readCachedPackageDecodesRawMojangJSONAndValidatesSHA1() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("1.20.4.json")

    // 空文件 → 未命中
    try Data().write(to: url)
    #expect(Mojang.readCachedPackage(at: url, expectedSHA1: "") == nil)

    // 原始 Mojang 版本 JSON → 解码为 .GameVersion
    try Data(minimalVersionJSON.utf8).write(to: url)
    let hit = try #require(Mojang.readCachedPackage(at: url, expectedSHA1: ""))
    guard case .GameVersion = hit else {
        Issue.record("应当解码为 GameVersion")
        return
    }

    // 哈希不符 → 未命中
    #expect(Mojang.readCachedPackage(at: url, expectedSHA1: String(repeating: "0", count: 40)) == nil)

    // 哈希匹配 → 命中
    let sha1 = Mojang.sha1Hex(Data(minimalVersionJSON.utf8))
    #expect(Mojang.readCachedPackage(at: url, expectedSHA1: sha1) != nil)
}
