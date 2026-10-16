//
//  Types+.swift
//  MojangAPI
//
//  Created by wangzhizhou on 2024/12/28.
//

import Foundation

public typealias Manifest = Components.Schemas.Manifest
public typealias Version = Components.Schemas.Version
public typealias BuildType = Components.Schemas.Version._TypePayload
public typealias GameVersion = Components.Schemas.GameVersion
public typealias GameVersionAsset = Components.Schemas.GameVersionAsset
public typealias UserInfo = Components.Schemas.UserInfo

extension Version: Identifiable {
    /// 从版本 URL 中解析包的 SHA1（路径段中的 40 位十六进制字符串）。
    /// - Returns: 小写 SHA1 字符串，若无法解析则为 nil。
    private var packageSHA1: String? {
        guard let versionURL = Foundation.URL(string: url) else { return nil }
        // 从路径组件中查找 40 位十六进制字符串
        for comp in versionURL.pathComponents {
            if comp.count == 40 && comp.allSatisfy({
                ("0123456789abcdefABCDEF").contains($0)
            }) {
                return comp.lowercased()
            }
        }
        return nil
    }
    /// 异步解析并返回该版本对应的包详情（GameVersion）。
    /// - Returns: `GameVersion`，若缓存未命中且返回非 GameVersion 则抛出 `cacheMiss`。
    /// - Throws: 当无法解析 SHA1 时抛出 `missingSHA1`，或网络/解析错误。
    public var gameVersion: GameVersion? {
        get async throws {
            guard let packageSHA1 = packageSHA1 else { throw MojangAPIError.missingSHA1 }
            if let gameVersion = try await APICache.shared.getGameVersion(id: id, sha1: packageSHA1, loader: { try await Mojang.fetchGameVersionPackage(id: id, sha1: packageSHA1) }) {
                return gameVersion
            }
            throw MojangAPIError.cacheMiss
        }
    }
    /// 版本类型（release/snapshot/oldAlpha/oldBeta）。
    public var buildType: BuildType {
        return self._type
    }
}

extension Components.Schemas.GameVersion {
    
    /// 异步获取资源索引对应的对象列表（GameVersionAsset）。
    /// - Returns: `GameVersionAsset`，若缓存未命中且返回非 GameVersionAsset 则抛出 `cacheMiss`。
    public var assetIndexObject: GameVersionAsset? {
        get async throws {
            if let assetIndex = try await APICache.shared.getAssetIndex(id: assetIndex.id, sha1: assetIndex.sha1, loader: { try await Mojang.fetchPackage(id: assetIndex.id, sha1: assetIndex.sha1) }) {
                return assetIndex
            }
            throw MojangAPIError.cacheMiss
        }
    }
}


extension Components.Schemas.Object {
    
    /// 构造该对象在资源服务器上的下载 URL。
    public var resourceURL: URL {
        let hostURL = (try? Servers.Server4.url()) ?? Foundation.URL(string: "https://resources.download.minecraft.net")!
        let path = "\(dirName)/\(fileName)"
        if #available(macOS 13.0, *) {
            return hostURL.appending(path: path)
        } else {
            return hostURL.appendingPathComponent(path)
        }
    }
    
    /// 资源目录名（哈希前两位）。
    public var dirName: String { String(hash.prefix(2)) }
    
    /// 资源文件名（哈希）。
    public var fileName: String { hash }
}
