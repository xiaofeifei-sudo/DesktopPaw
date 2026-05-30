import Foundation

public struct APIProviderConfig: Codable, Equatable, Sendable {
    public var aliyunModel: String
    public var aliyunRegion: String
    public var siliconFlowModel: String
    public var openaiCompatibleBaseURL: String
    public var openaiCompatibleModel: String
    public var tencentRegion: String

    public static let `default` = APIProviderConfig(
        aliyunModel: "wanx2.1-t2i-turbo",
        aliyunRegion: "cn-beijing",
        siliconFlowModel: "black-forest-labs/FLUX.1-schnell",
        openaiCompatibleBaseURL: "https://api.openai.com",
        openaiCompatibleModel: "dall-e-3",
        tencentRegion: "ap-guangzhou"
    )

    public init(
        aliyunModel: String = APIProviderConfig.default.aliyunModel,
        aliyunRegion: String = APIProviderConfig.default.aliyunRegion,
        siliconFlowModel: String = APIProviderConfig.default.siliconFlowModel,
        openaiCompatibleBaseURL: String = APIProviderConfig.default.openaiCompatibleBaseURL,
        openaiCompatibleModel: String = APIProviderConfig.default.openaiCompatibleModel,
        tencentRegion: String = APIProviderConfig.default.tencentRegion
    ) {
        self.aliyunModel = aliyunModel
        self.aliyunRegion = aliyunRegion
        self.siliconFlowModel = siliconFlowModel
        self.openaiCompatibleBaseURL = openaiCompatibleBaseURL
        self.openaiCompatibleModel = openaiCompatibleModel
        self.tencentRegion = tencentRegion
    }
}

public protocol APIProviderConfigStoring: Sendable {
    func load() -> APIProviderConfig
    func save(_ config: APIProviderConfig)
}

public final class APIProviderConfigStore: APIProviderConfigStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "apiProviderConfig"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> APIProviderConfig {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return .default }
        return (try? JSONDecoder().decode(APIProviderConfig.self, from: data)) ?? .default
    }

    public func save(_ config: APIProviderConfig) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }
}
