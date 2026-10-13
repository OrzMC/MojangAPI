import CacheKit
import Foundation

public struct Mojang {
    
     /// 获取指定类型的最新版本（生成类型）。
    /// - Parameters:
    ///   - type: 版本类型（release/snapshot/oldAlpha/oldBeta）。
    ///   - forceUpdate: 是否忽略缓存强制刷新清单。
    /// - Returns: 匹配的最新 `Version`，若不存在则为 nil。
    /// - Throws: 网络或解析相关错误。
    public static func latest(type: BuildType = .release, forceUpdate: Bool = true) async throws -> Version? {
        let manifest = try await manifest(forceUpdate: forceUpdate)
        let latestVersion = switch type {
        case .release:
            manifest.latest.release
        case .snapshot:
            manifest.latest.snapshot
        default:
            "" // TODO: old_beta、old_alpah
        }
        let latest = try await versions(id: latestVersion, type: type).first
        return latest
    }
    
    /// 按类型与可选关键字过滤版本（生成类型）。
    /// - Parameters:
    ///   - id: 版本号关键字（例如 "1.21"），为 nil 表示不过滤。
    ///   - type: 版本类型。
    ///   - forceUpdate: 是否忽略缓存强制刷新清单。
    /// - Returns: 过滤后的 `Version` 数组。
    /// - Throws: 网络或解析相关错误。
    public static func versions(id: String? = nil, type: BuildType = .release, forceUpdate: Bool = true) async throws -> [Version] {
        let versions = try await manifest(forceUpdate: forceUpdate).versions.filter { version in
            if let id {
                return version.buildType == type && version.id.contains(id)
            } else {
                return version.buildType == type
            }
        }
        return versions
    }
    
    /// 获取版本清单（落盘 TTL 缓存，默认 24h；`forceUpdate` 绕过缓存；失败回退旧副本）。
    /// - Parameter forceUpdate: 是否忽略缓存强制刷新。
    /// - Returns: `Manifest` 清单对象。
    /// - Throws: 网络或解析相关错误。
    public static func manifest(forceUpdate: Bool = true) async throws -> Manifest {
        do {
            let config = await Mojang.cacheConfig(refresh: forceUpdate)
            let cache = MetadataCache(directory: config.directory, policy: config.policy, refresh: config.refresh)
            let manifestURL = cache.fileURL("version_manifest.json")
            return try await cache.get(Manifest.self, at: manifestURL) {
                let output = try await Mojang.withRetry { try await manifestClient.getMinecraftGameVersionManifest() }
                return try output.jsonOrThrow()
            }
        } catch {
            throw MojangAPIError.wrap(error)
        }
    }
    
    
    /// 根据用户名查询 Mojang 用户信息（生成类型）。
    /// - Parameter name: 玩家用户名。
    /// - Returns: `UserInfo`，包含 id 与 name。
    /// - Throws: 当用户不存在或接口错误时抛出相应错误。
    public static func userInfo(with name: String) async throws -> UserInfo {
        do {
            let output = try await Mojang.withRetry { try await apiClient.getUserInfoWithName(path: .init(username: name)) }
            return try output.jsonOrThrow()
        } catch {
            throw MojangAPIError.wrap(error)
        }
    }
    
}

public extension Mojang {
    /// 获取指定类型的最新版本（传输对象）。
    /// - Parameters:
    ///   - type: 版本类型。
    ///   - forceUpdate: 是否忽略缓存强制刷新清单。
    /// - Returns: 最新 `VersionInfo`，若不存在则为 nil。
    static func latestInfo(type: BuildKind = .release, forceUpdate: Bool = true) async throws -> VersionInfo? {
        let summary = ManifestSummary(fromManifest: try await manifest(forceUpdate: forceUpdate))
        let id: String = {
            switch type {
            case .release: return summary.latestRelease
            case .snapshot: return summary.latestSnapshot
            case .oldBeta, .oldAlpha: return ""
            }
        }()
        let versions = try await versionsInfo(id: id.isEmpty ? nil : id, type: type, forceUpdate: forceUpdate)
        return versions.first
    }

    /// 按类型与关键字过滤版本（传输对象）。
    /// - Parameters:
    ///   - id: 版本号关键字（nil 表示不过滤）。
    ///   - type: 版本类型。
    ///   - forceUpdate: 是否忽略缓存强制刷新清单。
    /// - Returns: 过滤后的 `VersionInfo` 列表。
    static func versionsInfo(id: String? = nil, type: BuildKind = .release, forceUpdate: Bool = true) async throws -> [VersionInfo] {
        let summary = ManifestSummary(fromManifest: try await manifest(forceUpdate: forceUpdate))
        return summary.versions.filter { v in
            if let id { return v.type == type && v.id.contains(id) }
            return v.type == type
        }
    }

    /// 根据用户名查询用户资料（传输对象）。
    /// - Parameter name: 玩家用户名。
    /// - Returns: `UserProfile`，包含 id 与 name。
    static func userProfile(with name: String) async throws -> UserProfile {
        let info = try await userInfo(with: name)
        return UserProfile(name: info.name, id: info.id)
    }
}

public extension Mojang {
    /// 从版本 JSON 解析 Java 需求：读 `javaVersion.majorVersion`，缺失默认 8，
    /// **不按 MC 版本硬编码**（对齐 `docs/spec/behavior.md` B5）。离线、纯函数。
    static func javaRequirement(fromVersionJSON data: Data) throws -> JavaRequirement {
        struct Wrapper: Decodable {
            struct JavaVersion: Decodable { let majorVersion: Int? }
            let javaVersion: JavaVersion?
        }
        do {
            let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
            return JavaRequirement(majorVersion: wrapper.javaVersion?.majorVersion ?? JavaRequirement.defaultMajor)
        } catch {
            throw MojangAPIError.decodingFailed
        }
    }
}
