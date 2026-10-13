import Testing
import Foundation
import CacheKit
@testable import MojangAPI

@Test
func output_manifest_ok_json() throws {
    let latest = Components.Schemas.Latest(release: "1.21.4", snapshot: "1.21.4")
    let v = Components.Schemas.Version(id: "1.21.4", _type: .release, url: "https://piston-meta.mojang.com/v1/packages/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/1.21.4.json")
    let manifest = Components.Schemas.Manifest(latest: latest, versions: [v])
    let output: Operations.GetMinecraftGameVersionManifest.Output = .ok(.init(body: .json(manifest)))
    let decoded = try output.jsonOrThrow()
    #expect(decoded.latest.release == "1.21.4")
    #expect(!decoded.versions.isEmpty)
}

@Test
func output_package_ok_json() throws {
    let obj = Components.Schemas.Object(hash: "ab1234", size: 1.0)
    let payload = Components.Schemas.GameVersionAsset.ObjectsPayload(additionalProperties: ["a/b": obj])
    let asset = Components.Schemas.GameVersionAsset(objects: payload)
    let pkg = Components.Schemas.Package.GameVersionAsset(asset)
    let output: Operations.GetPackage.Output = .ok(.init(body: .json(pkg)))
    let decoded = try output.jsonOrThrow()
    switch decoded {
    case let .GameVersionAsset(v):
        #expect(v.objects.additionalProperties["a/b"]?.hash == "ab1234")
    default:
        #expect(Bool(false))
    }
}

@Test
func object_resource_url_building() throws {
    let obj = Components.Schemas.Object(hash: "ab1234", size: 1)
    let url = obj.resourceURL
    #expect(url.host() == "resources.download.minecraft.net")
    #expect(url.path().contains("ab/ab1234"))
}

@Test
func with_retry_behavior() async {
    await MainActor.run { Mojang.configureNetwork(retries: 1) }
    var attempts = 0
    do {
        let result = try await Mojang.withRetry {
            attempts += 1
            if attempts == 1 { throw MojangAPIError.requestFailed(status: 500) }
            return 42
        }
        #expect(result == 42)
    } catch {
        #expect(Bool(false))
    }
    await MainActor.run { Mojang.configureNetwork(retries: 0) }
    var attempts2 = 0
    do {
        _ = try await Mojang.withRetry {
            attempts2 += 1
            throw MojangAPIError.requestFailed(status: 500)
        }
        #expect(Bool(false))
    } catch {
        #expect(attempts2 == 1)
    }
}

@Test
func manifest_cache_uses_disk_ttl() async throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("mojangapi-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let cache = MetadataCache(directory: dir)
    let url = cache.fileURL("version_manifest.json")
    var calls = 0
    let first = try await cache.get(ManifestSummary.self, at: url) {
        calls += 1
        return ManifestSummary(latestRelease: "r", latestSnapshot: "s", versions: [])
    }
    let second = try await cache.get(ManifestSummary.self, at: url) {
        calls += 1
        return ManifestSummary(latestRelease: "r2", latestSnapshot: "s2", versions: [])
    }
    #expect(calls == 1)
    #expect(first.latestRelease == second.latestRelease)
}

@Test
func cache_asset_index_caching() async throws {
    let id = "dummy-id"
    let sha1 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    var calls = 0
    let first = try await APICache.shared.getAssetIndex(id: id, sha1: sha1, loader: {
        calls += 1
        let obj = Components.Schemas.Object(hash: "ab1234", size: 1.0)
        let payload = Components.Schemas.GameVersionAsset.ObjectsPayload(additionalProperties: ["a/b": obj])
        let asset = Components.Schemas.GameVersionAsset(objects: payload)
        return .GameVersionAsset(asset)
    })
    let second = try await APICache.shared.getAssetIndex(id: id, sha1: sha1, loader: {
        calls += 1
        let obj = Components.Schemas.Object(hash: "ab1234", size: 1.0)
        let payload = Components.Schemas.GameVersionAsset.ObjectsPayload(additionalProperties: ["a/b": obj])
        let asset = Components.Schemas.GameVersionAsset(objects: payload)
        return .GameVersionAsset(asset)
    })
    #expect(calls == 1)
    #expect(first?.objects.additionalProperties["a/b"]?.hash == second?.objects.additionalProperties["a/b"]?.hash)
}
