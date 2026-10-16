import CacheKit
import Foundation

/// 元数据缓存配置（D-c：统一缓存来自 `CacheKit`）。
///
/// 默认目录为 `~/Library/Caches/MojangAPI`，默认策略为 TTL 24h
/// （对齐 `docs/spec/behavior.md` B1）。调用方可注入目录/策略。
public extension Mojang {
    /// 设置缓存目录。
    @MainActor
    static func configureCache(directory: URL) {
        cacheDirectory = directory
    }

    /// 设置缓存策略。
    @MainActor
    static func configureCache(policy: CachePolicy) {
        cachePolicy = policy
    }

    /// 设置游戏版本 JSON 的磁盘缓存目录（应为 `<root>/cache`，与 Python `orzmc` 共享）。
    /// 传 `nil` 恢复「仅内存缓存」。
    @MainActor
    static func configurePackageCache(directory: URL?) {
        packageCacheDirectory = directory
    }
}

extension Mojang {
    @MainActor static var cacheDirectory: URL = Mojang.defaultCacheDirectory
    @MainActor static var cachePolicy: CachePolicy = .standard
    /// 游戏版本 JSON 缓存目录；`nil` 时只走内存 LRU（旧行为）。
    @MainActor static var packageCacheDirectory: URL?

    static var defaultCacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("MojangAPI", isDirectory: true)
    }

    /// 当前缓存配置（`URL` 与 `CachePolicy` 均为 `Sendable`，可跨隔离返回）。
    @MainActor
    static func cacheConfig(refresh: Bool) -> (directory: URL, policy: CachePolicy, refresh: Bool) {
        (cacheDirectory, cachePolicy, refresh)
    }
}