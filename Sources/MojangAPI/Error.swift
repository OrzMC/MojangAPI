import Foundation

public enum MojangAPIError: Error, Equatable {
    case invalidURL
    case requestFailed(status: Int)
    case decodingFailed
    case notFound
    case deprecatedEndpoint(String)
    case cacheMiss
    case missingSHA1
    case hashMismatch
    case unknown(String)
    case httpError(status: Int, code: Int?, message: String)
}

extension MojangAPIError {
    static func wrap(_ error: Error) -> MojangAPIError {
        let message = String(describing: error)
        return .unknown(message)
    }
}
