import Foundation

/// 版本类型枚举，独立于生成类型，便于向后兼容
public enum BuildKind: String, Codable, Equatable, Sendable {
    case release
    case snapshot
    case oldBeta = "old_beta"
    case oldAlpha = "old_alpha"
}

/// 规范渠道：非 release 一律归 snapshot（对齐 `docs/spec/behavior.md` B10）。
public enum BuildChannel: String, Codable, Equatable, Sendable {
    case release
    case snapshot
}

public extension BuildKind {
    var channel: BuildChannel {
        self == .release ? .release : .snapshot
    }
}

/// 基础版本信息 DTO，用于清单与查询返回
public struct VersionInfo: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: BuildKind
    public let url: String

    public init(id: String, type: BuildKind, url: String) {
        self.id = id
        self.type = type
        self.url = url
    }
}

/// 清单摘要 DTO，包含最新版本与版本列表。
///
/// 解码同时兼容两种格式：
/// - Mojang 原生清单：`{ "latest": { "release": ..., "snapshot": ... }, "versions": [...] }`
/// - 扁平摘要：`{ "latestRelease": ..., "latestSnapshot": ..., "versions": [...] }`
public struct ManifestSummary: Codable, Equatable {
    public let latestRelease: String
    public let latestSnapshot: String
    public let versions: [VersionInfo]

    public init(latestRelease: String, latestSnapshot: String, versions: [VersionInfo]) {
        self.latestRelease = latestRelease
        self.latestSnapshot = latestSnapshot
        self.versions = versions
    }

    /// 从生成的 Manifest 映射到 DTO
    public init(fromManifest m: Manifest) {
        let versions: [VersionInfo] = m.versions.map { v in
            let kind: BuildKind
            switch v._type {
            case .release: kind = .release
            case .snapshot: kind = .snapshot
            case .oldBeta: kind = .oldBeta
            case .oldAlpha: kind = .oldAlpha
            }
            return VersionInfo(id: v.id, type: kind, url: v.url)
        }
        self.init(latestRelease: m.latest.release, latestSnapshot: m.latest.snapshot, versions: versions)
    }

    private enum CodingKeys: String, CodingKey {
        case latest
        case versions
        case latestRelease
        case latestSnapshot
    }

    private struct Latest: Codable {
        let release: String
        let snapshot: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let latest = try container.decodeIfPresent(Latest.self, forKey: .latest) {
            latestRelease = latest.release
            latestSnapshot = latest.snapshot
        } else {
            latestRelease = try container.decode(String.self, forKey: .latestRelease)
            latestSnapshot = try container.decode(String.self, forKey: .latestSnapshot)
        }
        versions = try container.decode([VersionInfo].self, forKey: .versions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latestRelease, forKey: .latestRelease)
        try container.encode(latestSnapshot, forKey: .latestSnapshot)
        try container.encode(versions, forKey: .versions)
    }
}

public extension ManifestSummary {
    /// 过滤版本列表
    func filter(id: String? = nil, type: BuildKind = .release) -> [VersionInfo] {
        versions.filter { v in
            if let id { return v.type == type && v.id.contains(id) }
            return v.type == type
        }
    }

    /// 解析某个渠道对应的最新版本条目（对齐一致性操作 `resolveVersion`）。
    func resolve(_ channel: BuildChannel) -> VersionInfo? {
        let id = channel == .release ? latestRelease : latestSnapshot
        return versions.first { $0.id == id }
    }
}

/// 用户档案 DTO，用于对外稳定返回
public struct UserProfile: Codable, Equatable {
    public let name: String
    public let id: String
}

/// Java 运行时需求（对齐 `docs/spec/data-model.md` §4 / `behavior.md` B5）。
public struct JavaRequirement: Codable, Equatable, Sendable {
    public let majorVersion: Int
    public let distribution: String
    public let runtimeKind: String

    /// 缺失 `javaVersion` 时的默认主版本。
    public static let defaultMajor = 8

    public init(majorVersion: Int, distribution: String = "temurin", runtimeKind: String = "jre") {
        self.majorVersion = majorVersion
        self.distribution = distribution
        self.runtimeKind = runtimeKind
    }
}
