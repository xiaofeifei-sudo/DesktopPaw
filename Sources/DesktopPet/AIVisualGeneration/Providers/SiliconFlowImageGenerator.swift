import Foundation

public final class SiliconFlowImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = "siliconflow"
    public let displayName = "SiliconFlow"
    public let capabilities = VisualGenerationCapabilities(
        supportsReferenceImage: false,
        supportsImageEdit: false,
        supportsTransparentBackground: false,
        supportsQuotaSnapshot: false
    )

    private let httpClient: APIProviderHTTPExecuting
    private let keychain: KeychainStore
    private let configStore: APIProviderConfigStoring
    private let lock = NSLock()

    public init(
        httpClient: APIProviderHTTPExecuting = APIProviderHTTPClient(),
        keychain: KeychainStore = KeychainStore(),
        configStore: APIProviderConfigStoring = APIProviderConfigStore()
    ) {
        self.httpClient = httpClient
        self.keychain = keychain
        self.configStore = configStore
    }

    public var isConfigured: Bool {
        keychain.loadAPIKey(for: providerId) != nil
    }

    public func saveAPIKey(_ key: String) -> Bool {
        keychain.saveAPIKey(key, for: providerId)
    }

    public func deleteAPIKey() -> Bool {
        keychain.deleteAPIKey(for: providerId)
    }

    public func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        guard let apiKey = keychain.loadAPIKey(for: providerId) else {
            throw VisualGenerationError.notConfigured(providerId: providerId)
        }

        let model = configStore.load().siliconFlowModel
        let size = aspectRatioToSize(request.aspectRatio)

        let body: [String: Any] = [
            "model": model,
            "prompt": request.prompt,
            "image_size": size,
            "batch_size": request.count
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.siliconflow.cn/v1/images/generations")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: APIProviderHTTPResponse
        do {
            response = try await httpClient.execute(urlRequest)
        } catch {
            throw VisualGenerationError.network(providerId: providerId, underlying: error.localizedDescription)
        }

        guard response.statusCode == 200 else {
            throw mapError(response)
        }

        guard let imageURL = parseImageURL(from: response.data) else {
            throw VisualGenerationError.invalidOutput(providerId: providerId, reason: "No image URL in response")
        }

        let localURL = try await downloadAndSave(imageURL: imageURL, request: request)
        return VisualGenerationResult(actionId: request.actionId, imageURL: localURL, providerId: providerId)
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        nil
    }

    private func parseImageURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let images = json["images"] as? [[String: Any]],
           let first = images.first,
           let urlStr = first["url"] as? String {
            return URL(string: urlStr)
        }
        return nil
    }

    private func mapError(_ response: APIProviderHTTPResponse) -> VisualGenerationError {
        let body = String(data: response.data, encoding: .utf8) ?? ""
        if response.statusCode == 401 {
            return VisualGenerationError.notConfigured(providerId: providerId)
        }
        if response.statusCode == 429 || body.contains("quota") || body.contains("limit") {
            return VisualGenerationError.quotaExceeded(providerId: providerId)
        }
        if response.statusCode >= 500 {
            return VisualGenerationError.network(providerId: providerId, underlying: "Server error \(response.statusCode)")
        }
        return VisualGenerationError.invalidOutput(providerId: providerId, reason: "HTTP \(response.statusCode): \(body.prefix(200))")
    }

    private func downloadAndSave(imageURL: URL, request: VisualGenerationRequest) async throws -> URL {
        let imageData: Data
        do {
            imageData = try await httpClient.downloadData(from: imageURL)
        } catch {
            throw VisualGenerationError.network(providerId: providerId, underlying: "Image download failed: \(error.localizedDescription)")
        }

        try FileManager.default.createDirectory(at: request.outputDirectory, withIntermediateDirectories: true)
        let localURL = request.outputDirectory.appendingPathComponent("\(request.outputPrefix).png")
        try imageData.write(to: localURL)
        return localURL
    }

    private func aspectRatioToSize(_ ratio: String) -> String {
        switch ratio {
        case "1:1": return "1024x1024"
        case "16:9": return "1024x576"
        case "9:16": return "576x1024"
        default: return "1024x1024"
        }
    }
}
