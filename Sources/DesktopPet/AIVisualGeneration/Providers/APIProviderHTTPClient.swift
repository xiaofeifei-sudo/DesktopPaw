import Foundation

public protocol APIProviderHTTPExecuting: Sendable {
    func execute(_ request: URLRequest) async throws -> APIProviderHTTPResponse
    func downloadData(from url: URL) async throws -> Data
}

public struct APIProviderHTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public final class APIProviderHTTPClient: APIProviderHTTPExecuting, @unchecked Sendable {
    private let session: URLSession

    public init(timeoutInterval: TimeInterval = 90) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval + 30
        self.session = URLSession(configuration: config)
    }

    public func execute(_ request: URLRequest) async throws -> APIProviderHTTPResponse {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        return APIProviderHTTPResponse(statusCode: statusCode, data: data)
    }

    public func downloadData(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
