import Foundation

public final class MiniMaxAPIImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = "minimax-api"
    public let displayName = "MiniMax API"
    public let capabilities = VisualGenerationCapabilities(
        supportsReferenceImage: true,
        supportsImageEdit: false,
        supportsTransparentBackground: false,
        supportsQuotaSnapshot: false
    )

    private let httpClient: APIProviderHTTPExecuting
    private let keychain: KeychainStore
    private let lock = NSLock()

    public init(
        httpClient: APIProviderHTTPExecuting = APIProviderHTTPClient(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.httpClient = httpClient
        self.keychain = keychain
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

        var body: [String: Any] = [
            "model": "image-01",
            "prompt": request.prompt,
            "aspect_ratio": request.aspectRatio.replacingOccurrences(of: ":", with: ":"),
            "n": request.count
        ]

        if let refURL = request.referenceImageURL {
            let refData = try Data(contentsOf: refURL)
            let base64 = refData.base64EncodedString()
            let mimeType = refURL.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
            body["subject_reference"] = [
                ["type": "character", "image_base64": "data:\(mimeType);base64,\(base64)"]
            ]
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.minimax.chat/v1/image_generation")!)
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
        if let dataDict = json["data"] as? [String: Any],
           let urls = dataDict["image_urls"] as? [String],
           let first = urls.first {
            return URL(string: first)
        }
        if let baseInfo = json["base_resp"] as? [String: Any],
           let statusCode = baseInfo["status_code"] as? Int, statusCode != 0 {
            return nil
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
}
