import Foundation

public final class AliyunImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = "aliyun"
    public let displayName = "Aliyun Bailian"
    public let capabilities = VisualGenerationCapabilities(
        supportsReferenceImage: false,
        supportsImageEdit: false,
        supportsTransparentBackground: false,
        supportsQuotaSnapshot: false
    )

    private let httpClient: APIProviderHTTPExecuting
    private let keychain: KeychainStore
    private let configStore: APIProviderConfigStoring

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

        let config = configStore.load()
        let size = aspectRatioToSize(request.aspectRatio)

        let body: [String: Any] = [
            "model": config.aliyunModel,
            "input": ["prompt": request.prompt],
            "parameters": [
                "size": size,
                "n": request.count
            ]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: APIProviderHTTPResponse
        do {
            response = try await httpClient.execute(urlRequest)
        } catch {
            throw VisualGenerationError.network(providerId: providerId, underlying: error.localizedDescription)
        }

        if response.statusCode == 200 {
            if let taskID = parseAsyncTaskID(from: response.data) {
                return try await pollAsyncResult(taskID: taskID, apiKey: apiKey, request: request)
            }
        }

        if let imageURL = parseSyncImageURL(from: response.data) {
            let localURL = try await downloadAndSave(imageURL: imageURL, request: request)
            return VisualGenerationResult(actionId: request.actionId, imageURL: localURL, providerId: providerId)
        }

        if response.statusCode != 200 {
            throw mapError(response)
        }

        throw VisualGenerationError.invalidOutput(providerId: providerId, reason: "No task ID or image URL in response")
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        nil
    }

    private func parseAsyncTaskID(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let output = json["output"] as? [String: Any]
        return output?["task_id"] as? String
    }

    private func parseSyncImageURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let output = json["output"] as? [String: Any]
        let results = output?["results"] as? [[String: Any]]
        guard let first = results?.first,
              let urlStr = first["url"] as? String else { return nil }
        return URL(string: urlStr)
    }

    private func pollAsyncResult(taskID: String, apiKey: String, request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        let pollURL = URL(string: "https://dashscope.aliyuncs.com/api/v1/tasks/\(taskID)")!
        var urlRequest = URLRequest(url: pollURL)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let maxAttempts = 60
        let interval: UInt64 = 2_000_000_000

        for _ in 0..<maxAttempts {
            let response = try await httpClient.execute(urlRequest)

            guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                throw VisualGenerationError.invalidOutput(providerId: providerId, reason: "Invalid poll response")
            }

            let output = json["output"] as? [String: Any]
            let taskStatus = output?["task_status"] as? String ?? ""

            if taskStatus == "SUCCEEDED" {
                let results = output?["results"] as? [[String: Any]]
                guard let first = results?.first,
                      let urlStr = first["url"] as? String,
                      let imageURL = URL(string: urlStr) else {
                    throw VisualGenerationError.invalidOutput(providerId: providerId, reason: "No image URL in async result")
                }
                let localURL = try await downloadAndSave(imageURL: imageURL, request: request)
                return VisualGenerationResult(actionId: request.actionId, imageURL: localURL, providerId: providerId)
            }

            if taskStatus == "FAILED" {
                let message = output?["message"] as? String ?? "Unknown error"
                throw VisualGenerationError.invalidOutput(providerId: providerId, reason: message)
            }

            try await Task.sleep(nanoseconds: interval)
        }

        throw VisualGenerationError.timeout(providerId: providerId)
    }

    private func mapError(_ response: APIProviderHTTPResponse) -> VisualGenerationError {
        let body = String(data: response.data, encoding: .utf8) ?? ""
        if response.statusCode == 401 || response.statusCode == 403 {
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
        case "1:1": return "1024*1024"
        case "16:9": return "1024*576"
        case "9:16": return "576*1024"
        default: return "1024*1024"
        }
    }
}
