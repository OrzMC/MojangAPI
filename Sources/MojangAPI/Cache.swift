import Foundation

actor APICache {
    static let shared = APICache()

    private struct GameVersionEntry { var value: GameVersion; var lastAccess: Date }
    private struct AssetIndexEntry { var value: GameVersionAsset; var lastAccess: Date }
    private var gameVersionsById: [String: GameVersionEntry] = [:]
    private var assetIndicesById: [String: AssetIndexEntry] = [:]
    private let gameVersionCapacity = 128
    private let assetIndexCapacity = 128

    /// 获取指定版本 id 对应的 GameVersion（带 LRU 缓存）。
    /// - Parameters:
    ///   - id: 版本号。
    ///   - sha1: 包的 SHA1。
    ///   - loader: 包加载器，返回 Package。
    /// - Returns: 命中时返回 GameVersion，否则为 nil。
    func getGameVersion(id: String, sha1: String, loader: () async throws -> Components.Schemas.Package) async throws -> GameVersion? {
        if var entry = gameVersionsById[id] {
            entry.lastAccess = Date()
            gameVersionsById[id] = entry
            return entry.value
        }
        let packageOutput = try await loader()
        if case let .GameVersion(gameVersion) = packageOutput {
            evictIfNeededGameVersions()
            gameVersionsById[id] = GameVersionEntry(value: gameVersion, lastAccess: Date())
            return gameVersion
        }
        return nil
    }

    /// 获取资源索引对应的 GameVersionAsset（带 LRU 缓存）。
    /// - Parameters:
    ///   - id: 资源索引 id。
    ///   - sha1: 资源索引的 SHA1。
    ///   - loader: 包加载器，返回 Package。
    /// - Returns: 命中时返回 GameVersionAsset，否则为 nil。
    func getAssetIndex(id: String, sha1: String, loader: () async throws -> Components.Schemas.Package) async throws -> GameVersionAsset? {
        if var entry = assetIndicesById[id] {
            entry.lastAccess = Date()
            assetIndicesById[id] = entry
            return entry.value
        }
        let packageOutput = try await loader()
        if case let .GameVersionAsset(assetIndex) = packageOutput {
            evictIfNeededAssetIndices()
            assetIndicesById[id] = AssetIndexEntry(value: assetIndex, lastAccess: Date())
            return assetIndex
        }
        return nil
    }

    private func evictIfNeededGameVersions() {
        if gameVersionsById.count >= gameVersionCapacity, let (key, _) = gameVersionsById.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
            gameVersionsById.removeValue(forKey: key)
        }
    }

    private func evictIfNeededAssetIndices() {
        if assetIndicesById.count >= assetIndexCapacity, let (key, _) = assetIndicesById.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
            assetIndicesById.removeValue(forKey: key)
        }
    }
}
