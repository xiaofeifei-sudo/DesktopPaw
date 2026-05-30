import CommonCrypto
import Foundation

public final class TencentImageGenerator: VisualImageGenerating, @unchecked Sendable {
    public let providerId = "tencent"
    public let displayName = "Tencent Hunyuan"
    public let capabilities = VisualGenerationCapabilities(
        supportsReferenceImage: false,
        supportsImageEdit: false,
        supportsTransparentBackground: false,
        supportsQuotaSnapshot: false
    )

    private let httpClient: APIProviderHTTPExecuting
    private let keychain: KeychainStore
    private let configStore: APIProviderConfigStoring
    private let service = "hunyuan.tencentcloudapi.com"

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
        keychain.loadAPIKey(for: "\(providerId)-secret-id") != nil
            && keychain.loadAPIKey(for: "\(providerId)-secret-key") != nil
    }

    public func saveCredentials(secretId: String, secretKey: String) -> Bool {
        keychain.saveAPIKey(secretId, for: "\(providerId)-secret-id")
            && keychain.saveAPIKey(secretKey, for: "\(providerId)-secret-key")
    }

    public func deleteCredentials() -> Bool {
        keychain.deleteAPIKey(for: "\(providerId)-secret-id")
            && keychain.deleteAPIKey(for: "\(providerId)-secret-key")
    }

    public func generate(_ request: VisualGenerationRequest) async throws -> VisualGenerationResult {
        guard let secretId = keychain.loadAPIKey(for: "\(providerId)-secret-id"),
              let secretKey = keychain.loadAPIKey(for: "\(providerId)-secret-key") else {
            throw VisualGenerationError.notConfigured(providerId: providerId)
        }

        let config = configStore.load()
        let payload = buildPayload(request: request)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let payloadStr = String(data: payloadData, encoding: .utf8) ?? ""

        let timestamp = Int(Date().timeIntervalSince1970)
        let date = formatDate(timestamp: timestamp)

        let signedHeaders = "content-type;host;x-tc-action"
        let canonicalRequest = "POST\n/\n\ncontent-type:application/json\nhost:\(service)\nx-tc-action:TextToImage\n\n\(signedHeaders)\n\(sha256Hex(payloadStr))"
        let credentialScope = "\(date)/hunyuan/tc3_request"
        let stringToSign = "TC3-HMAC-SHA256\n\(timestamp)\n\(credentialScope)\n\(sha256Hex(canonicalRequest))"
        let signature = calculateSignature(secretKey: secretKey, date: date, stringToSign: stringToSign)
        let authorization = "TC3-HMAC-SHA256 Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var urlRequest = URLRequest(url: URL(string: "https://\(service)")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(service, forHTTPHeaderField: "Host")
        urlRequest.setValue("TextToImage", forHTTPHeaderField: "X-TC-Action")
        urlRequest.setValue(config.tencentRegion, forHTTPHeaderField: "X-TC-Region")
        urlRequest.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        urlRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = payloadData

        let response: APIProviderHTTPResponse
        do {
            response = try await httpClient.execute(urlRequest)
        } catch {
            throw VisualGenerationError.network(providerId: providerId, underlying: error.localizedDescription)
        }

        guard response.statusCode == 200 else {
            throw mapError(response)
        }

        if let apiError = parseError(from: response.data) {
            throw apiError
        }

        guard let resultURL = parseResultURL(from: response.data) else {
            throw VisualGenerationError.invalidOutput(providerId: providerId, reason: "No result image in response")
        }

        let localURL = try await downloadAndSave(imageURL: resultURL, request: request)
        return VisualGenerationResult(actionId: request.actionId, imageURL: localURL, providerId: providerId)
    }

    public func quotaSnapshot() async throws -> VisualProviderQuotaSnapshot? {
        nil
    }

    private func buildPayload(request: VisualGenerationRequest) -> [String: Any] {
        let size = aspectRatioToSize(request.aspectRatio)
        return [
            "Prompt": request.prompt,
            "RspImgType": "url",
            "OutputFormat": "png",
            "LogoAdd": 0
        ].merging(sizeComponents(size)) { _, new in new }
    }

    private func sizeComponents(_ size: String) -> [String: Any] {
        let parts = size.split(separator: "x").compactMap { Int($0) }
        guard parts.count == 2 else { return ["Width": 1024, "Height": 1024] }
        return ["Width": parts[0], "Height": parts[1]]
    }

    private func parseResultURL(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let response = json["Response"] as? [String: Any]
        guard let urlStr = response?["ResultImage"] as? String, urlStr.hasPrefix("http") else { return nil }
        return URL(string: urlStr)
    }

    private func parseError(from data: Data) -> VisualGenerationError? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["Response"] as? [String: Any],
              let error = response["Error"] as? [String: Any] else { return nil }
        let code = error["Code"] as? String ?? ""
        if code.contains("AuthFailure") {
            return VisualGenerationError.notConfigured(providerId: providerId)
        }
        if code.contains("LimitExceeded") || code.contains("ResourcesSoldOut") {
            return VisualGenerationError.quotaExceeded(providerId: providerId)
        }
        return VisualGenerationError.invalidOutput(providerId: providerId, reason: "\(code): \(error["Message"] as? String ?? "")")
    }

    private func mapError(_ response: APIProviderHTTPResponse) -> VisualGenerationError {
        let body = String(data: response.data, encoding: .utf8) ?? ""
        if body.contains("AuthFailure") {
            return VisualGenerationError.notConfigured(providerId: providerId)
        }
        if body.contains("LimitExceeded") || body.contains("ResourcesSoldOut") {
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

    private func formatDate(timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func hmacSHA256(key: Data, data: String) -> Data {
        let dataBytes = Data(data.utf8)
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            dataBytes.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, dataBytes.baseAddress, dataBytes.count, &hmac)
            }
        }
        return Data(hmac)
    }

    private func calculateSignature(secretKey: String, date: String, stringToSign: String) -> String {
        let secretDate = hmacSHA256(key: Data("TC3\(secretKey)".utf8), data: date)
        let secretService = hmacSHA256(key: secretDate, data: "hunyuan")
        let secretSigning = hmacSHA256(key: secretService, data: "tc3_request")
        let signature = hmacSHA256(key: secretSigning, data: stringToSign)
        return signature.map { String(format: "%02x", $0) }.joined()
    }
}
