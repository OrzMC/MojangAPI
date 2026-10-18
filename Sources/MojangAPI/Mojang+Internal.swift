//
//  Mojang+Internal.swift
//  MojangAPI
//
//  Created by wangzhizhou on 2024/12/28.
//

// Apple 平台有 CryptoKit；Linux/Windows 用 swift-crypto 的 `Crypto`（决策 D8：跨平台）。
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
import Foundation

// Linux/Windows 把 URLSession/URLRequest 放在 FoundationNetworking（决策 D8：跨平台）。
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OpenAPIRuntime
import OpenAPIURLSession

// Internal
extension Mojang {
    @MainActor private static var retryCount: Int = 1
    @MainActor static func configureNetwork(retries: Int) { retryCount = max(0, retries) }
    @MainActor private static func currentRetryCount() -> Int { retryCount }

    static func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let maxRetries = await currentRetryCount()
        var attempts = maxRetries
        do {
            return try await operation()
        } catch {
            while attempts > 0 {
                attempts -= 1
                do { return try await operation() } catch { continue }
            }
            throw error
        }
    }

    static var manifestClient: Client {
        Client(
            serverURL: (try? Servers.Server1.url()) ?? Foundation.URL(string: "https://launchermeta.mojang.com")!,
            transport: URLSessionTransport()
        )
    }
    
    static func fetchPackage(id: String, sha1: String) async throws -> Components.Schemas.Package {
        let output = try await withRetry { try await packageClient.getPackage(path: .init(sha1: sha1, id: id)) }
        return try output.jsonOrThrow()
    }

    /// 游戏版本 JSON：在内存 LRU 之外可选一层磁盘缓存。
    ///
    /// 配置了 `packageCacheDirectory` 时，**原始 Mojang JSON** 落到
    /// `<dir>/versions/<id>.json`（与 Python `orzmc` 的 `<root>/cache/versions/<v>.json` 同路径同字节，可互读）。
    /// 逐字节保留是刻意的：Python 侧按清单 sha1 校验缓存，重编码过的 JSON 会哈希不符而被丢弃。
    /// 未配置时行为不变（仅内存）。
    static func fetchGameVersionPackage(id: String, sha1: String) async throws -> Components.Schemas.Package {
        guard let directory = await Mojang.packageCacheDirectory else {
            return try await fetchPackage(id: id, sha1: sha1)
        }
        let fileURL = directory
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent("\(id).json")
        if let cached = readCachedPackage(at: fileURL, expectedSHA1: sha1) {
            return cached
        }
        let data = try await fetchRawPackageData(id: id, sha1: sha1)
        if !sha1.isEmpty, sha1Hex(data) != sha1.lowercased() {
            throw MojangAPIError.hashMismatch
        }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
        return try JSONDecoder().decode(Components.Schemas.Package.self, from: data)
    }

    /// 直接取原始字节（生成客户端只暴露已解码的 `Package`，无法逐字节落盘）。
    static func fetchRawPackageData(id: String, sha1: String) async throws -> Data {
        let base = (try? Servers.Server2.url()) ?? Foundation.URL(string: "https://piston-meta.mojang.com")!
        let url = base.appendingPathComponent("v1/packages/\(sha1)/\(id).json")
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 404 { throw MojangAPIError.notFound }
            throw MojangAPIError.requestFailed(status: http.statusCode)
        }
        return data
    }

    /// 读磁盘上的原始 JSON 并解码；`expectedSHA1` 非空且不符时视为未命中。
    static func readCachedPackage(at url: URL, expectedSHA1: String) -> Components.Schemas.Package? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        if !expectedSHA1.isEmpty, sha1Hex(data) != expectedSHA1.lowercased() { return nil }
        return try? JSONDecoder().decode(Components.Schemas.Package.self, from: data)
    }

    static func sha1Hex(_ data: Data) -> String {
        Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    
    // Deprecated auth client removed
    
    static var apiClient: Client {
        Client(
            serverURL: (try? Servers.Server5.url()) ?? Foundation.URL(string: "https://api.mojang.com")!,
            transport: URLSessionTransport()
        )
    }
}

// Private
extension Mojang {
    private static var packageClient: Client {
        Client(
            serverURL: (try? Servers.Server2.url()) ?? Foundation.URL(string: "https://piston-meta.mojang.com")!,
            transport: URLSessionTransport()
        )
    }
}
