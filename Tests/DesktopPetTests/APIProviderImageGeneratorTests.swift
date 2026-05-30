import DesktopPet
import Foundation

@MainActor
func runAPIProviderImageGeneratorTests() async throws {
    let tests = APIProviderImageGeneratorTests()
    tests.minimaxAPIIsConfiguredWithAPIKey()
    tests.minimaxAPINotConfiguredWithoutAPIKey()
    try await tests.minimaxAPIGeneratesImage()
    try await tests.minimaxAPIThrowsNotConfigured()
    try await tests.minimaxAPIMapsHTTPError()
    try await tests.minimaxAPISupportsReferenceImage()
    tests.siliconFlowIsConfiguredWithAPIKey()
    try await tests.siliconFlowGeneratesImage()
    try await tests.siliconFlowThrowsNotConfigured()
    try await tests.siliconFlowMapsQuotaError()
    tests.openAICompatibleIsConfigured()
    try await tests.openAICompatibleGeneratesImage()
    try await tests.openAICompatibleThrowsNotConfiguredWithoutBaseURL()
    tests.aliyunIsConfiguredWithAPIKey()
    try await tests.aliyunGeneratesImage()
    try await tests.aliyunMapsAuthError()
    tests.tencentIsConfiguredWithCredentials()
    tests.tencentNotConfiguredWithPartialCredentials()
    try await tests.tencentGeneratesImage()
    try await tests.tencentMapsAuthError()
    tests.apiProviderConfigStoreRoundTrip()
    tests.apiProviderConfigStoreReturnsDefault()
}

@MainActor
struct APIProviderImageGeneratorTests {
    private func makeRequest(actionId: String = "act-1") -> VisualGenerationRequest {
        VisualGenerationRequest(
            actionId: actionId,
            petId: "pet-1",
            prompt: "a happy cat wearing a hat",
            referenceImageURL: nil,
            aspectRatio: "1:1",
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("api-test-\(UUID().uuidString)"),
            outputPrefix: "act-1"
        )
    }

    private func makeRequestWithRef(actionId: String = "act-ref") -> VisualGenerationRequest {
        VisualGenerationRequest(
            actionId: actionId,
            petId: "pet-1",
            prompt: "same cat but with a hat",
            referenceImageURL: URL(fileURLWithPath: "/tmp/fake-reference.png"),
            aspectRatio: "1:1",
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("api-test-\(UUID().uuidString)"),
            outputPrefix: actionId
        )
    }

    // MARK: - MiniMax API

    func minimaxAPIIsConfiguredWithAPIKey() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")
        expect(provider.isConfigured == true, "MiniMax API should be configured with API key")
        expect(provider.providerId == "minimax-api", "providerId should be minimax-api")
        expect(provider.displayName == "MiniMax API", "displayName should be MiniMax API")
        expect(provider.capabilities.supportsReferenceImage == true, "should support reference image")
        expect(provider.capabilities.supportsQuotaSnapshot == false, "should not support quota snapshot")
        _ = provider.deleteAPIKey()
    }

    func minimaxAPINotConfiguredWithoutAPIKey() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)
        expect(provider.isConfigured == false, "MiniMax API should not be configured without API key")
    }

    func minimaxAPIGeneratesImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: ["data": ["image_urls": ["https://example.com/img.png"]]])
        )
        client.stubDownloadData = imageData

        let request = makeRequest()
        let result = try await provider.generate(request)
        expect(result.providerId == "minimax-api", "result should have minimax-api providerId")
        expect(result.actionId == "act-1", "result should have correct actionId")
        expect(client.lastRequest != nil, "should have made an HTTP request")
        expect(client.lastRequest?.url?.absoluteString.contains("api.minimax.chat") == true, "should call MiniMax API endpoint")

        let authHeader = client.lastRequest?.value(forHTTPHeaderField: "Authorization")
        expect(authHeader == "Bearer test-key", "should send Bearer token")

        _ = provider.deleteAPIKey()
    }

    func minimaxAPIThrowsNotConfigured() async {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw notConfigured")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "minimax-api", "should identify provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func minimaxAPIMapsHTTPError() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 429,
            data: Data("rate limited".utf8)
        )

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .quotaExceeded(let id) = error {
                expect(id == "minimax-api", "should map 429 to quotaExceeded")
            } else {
                fail("expected quotaExceeded, got \(error)")
            }
        }

        _ = provider.deleteAPIKey()
    }

    func minimaxAPISupportsReferenceImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = MiniMaxAPIImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: ["data": ["image_urls": ["https://example.com/img.png"]]])
        )
        client.stubDownloadData = imageData

        let refURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ref-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: refURL)
        defer { try? FileManager.default.removeItem(at: refURL) }

        let request = VisualGenerationRequest(
            actionId: "act-ref",
            petId: "pet-1",
            prompt: "same cat with hat",
            referenceImageURL: refURL,
            aspectRatio: "1:1",
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("api-test-\(UUID().uuidString)"),
            outputPrefix: "act-ref"
        )

        let result = try await provider.generate(request)
        expect(result.providerId == "minimax-api", "should generate with reference image")

        let bodyData = client.lastRequest?.httpBody
        expect(bodyData != nil, "should have request body")
        if let body = bodyData,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let subjectRef = json["subject_reference"] as? [[String: Any]] {
            expect(subjectRef.count == 1, "should include subject_reference")
            expect(subjectRef[0]["type"] as? String == "character", "should be character type")
            let base64 = subjectRef[0]["image_base64"] as? String ?? ""
            expect(base64.hasPrefix("data:image/png;base64,"), "should be base64 data URL")
        }

        _ = provider.deleteAPIKey()
    }

    // MARK: - SiliconFlow

    func siliconFlowIsConfiguredWithAPIKey() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = SiliconFlowImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")
        expect(provider.isConfigured == true, "SiliconFlow should be configured with API key")
        expect(provider.providerId == "siliconflow", "providerId should be siliconflow")
        expect(provider.capabilities.supportsReferenceImage == false, "should not support reference image")
        _ = provider.deleteAPIKey()
    }

    func siliconFlowGeneratesImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = SiliconFlowImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: ["images": [["url": "https://example.com/img.png"]]])
        )
        client.stubDownloadData = imageData

        let result = try await provider.generate(makeRequest())
        expect(result.providerId == "siliconflow", "result should have siliconflow providerId")
        expect(client.lastRequest?.url?.absoluteString.contains("siliconflow") == true, "should call SiliconFlow endpoint")

        _ = provider.deleteAPIKey()
    }

    func siliconFlowThrowsNotConfigured() async {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = SiliconFlowImageGenerator(httpClient: client, keychain: keychain)

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "siliconflow", "should identify provider")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        } catch {
            fail("unexpected error type: \(error)")
        }
    }

    func siliconFlowMapsQuotaError() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = SiliconFlowImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 401,
            data: Data("unauthorized".utf8)
        )

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .notConfigured = error {
                expect(true, "401 should map to notConfigured")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        }

        _ = provider.deleteAPIKey()
    }

    // MARK: - OpenAI Compatible

    func openAICompatibleIsConfigured() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let configStore = FakeAPIProviderConfigStore()
        let provider = OpenAICompatibleImageGenerator(httpClient: client, keychain: keychain, configStore: configStore)
        _ = provider.saveAPIKey("test-key")
        expect(provider.isConfigured == true, "OpenAI Compatible should be configured with API key and base URL")
        expect(provider.providerId == "openai-compatible", "providerId should be openai-compatible")
    }

    func openAICompatibleGeneratesImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let configStore = FakeAPIProviderConfigStore()
        let provider = OpenAICompatibleImageGenerator(httpClient: client, keychain: keychain, configStore: configStore)
        _ = provider.saveAPIKey("test-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: ["data": [["url": "https://example.com/img.png"]]])
        )
        client.stubDownloadData = imageData

        let result = try await provider.generate(makeRequest())
        expect(result.providerId == "openai-compatible", "result should have openai-compatible providerId")
        expect(client.lastRequest?.url?.absoluteString.contains("/v1/images/generations") == true, "should call OpenAI images endpoint")

        _ = provider.deleteAPIKey()
    }

    func openAICompatibleThrowsNotConfiguredWithoutBaseURL() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        var customConfig = APIProviderConfig.default
        customConfig.openaiCompatibleBaseURL = ""
        let configStore = FakeAPIProviderConfigStore(config: customConfig)
        let provider = OpenAICompatibleImageGenerator(httpClient: client, keychain: keychain, configStore: configStore)
        _ = provider.saveAPIKey("test-key")

        expect(provider.isConfigured == false, "should not be configured with empty base URL")

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .notConfigured = error {
                expect(true, "empty base URL should cause notConfigured")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        }
    }

    // MARK: - Aliyun

    func aliyunIsConfiguredWithAPIKey() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = AliyunImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")
        expect(provider.isConfigured == true, "Aliyun should be configured with API key")
        expect(provider.providerId == "aliyun", "providerId should be aliyun")
        expect(provider.displayName == "Aliyun Bailian", "displayName should be Aliyun Bailian")
        _ = provider.deleteAPIKey()
    }

    func aliyunGeneratesImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = AliyunImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: ["output": ["results": [["url": "https://example.com/img.png"]]]])
        )
        client.stubDownloadData = imageData

        let result = try await provider.generate(makeRequest())
        expect(result.providerId == "aliyun", "result should have aliyun providerId")
        expect(client.lastRequest?.url?.absoluteString.contains("dashscope") == true, "should call DashScope endpoint")

        _ = provider.deleteAPIKey()
    }

    func aliyunMapsAuthError() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = AliyunImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveAPIKey("test-key")

        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 403,
            data: Data("forbidden".utf8)
        )

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "aliyun", "403 should map to notConfigured")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        }

        _ = provider.deleteAPIKey()
    }

    // MARK: - Tencent

    func tencentIsConfiguredWithCredentials() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = TencentImageGenerator(httpClient: client, keychain: keychain)
        let ok = provider.saveCredentials(secretId: "sid", secretKey: "skey")
        expect(ok == true, "should save credentials")
        expect(provider.isConfigured == true, "Tencent should be configured with credentials")
        expect(provider.providerId == "tencent", "providerId should be tencent")
        expect(provider.displayName == "Tencent Hunyuan", "displayName should be Tencent Hunyuan")
        _ = provider.deleteCredentials()
    }

    func tencentNotConfiguredWithPartialCredentials() {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = TencentImageGenerator(httpClient: client, keychain: keychain)
        expect(provider.isConfigured == false, "should not be configured without credentials")
    }

    func tencentGeneratesImage() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = TencentImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveCredentials(secretId: "test-secret-id", secretKey: "test-secret-key")

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: [
                "Response": ["ResultImage": "https://example.com/img.png", "RequestId": "req-1"]
            ])
        )
        client.stubDownloadData = imageData

        let result = try await provider.generate(makeRequest())
        expect(result.providerId == "tencent", "result should have tencent providerId")
        expect(client.lastRequest?.url?.absoluteString.contains("hunyuan.tencentcloudapi.com") == true, "should call Hunyuan endpoint")

        let authHeader = client.lastRequest?.value(forHTTPHeaderField: "Authorization")
        expect(authHeader?.hasPrefix("TC3-HMAC-SHA256") == true, "should use TC3-HMAC-SHA256 signing")

        let actionHeader = client.lastRequest?.value(forHTTPHeaderField: "X-TC-Action")
        expect(actionHeader == "TextToImage", "should set TextToImage action")

        _ = provider.deleteCredentials()
    }

    func tencentMapsAuthError() async throws {
        let keychain = KeychainStore(service: "com.desktoppet.test.\(UUID().uuidString)")
        let client = FakeHTTPClient()
        let provider = TencentImageGenerator(httpClient: client, keychain: keychain)
        _ = provider.saveCredentials(secretId: "sid", secretKey: "skey")

        client.stubResponse = APIProviderHTTPResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: [
                "Response": ["Error": ["Code": "AuthFailure", "Message": "invalid signature"], "RequestId": "req-1"]
            ])
        )

        do {
            _ = try await provider.generate(makeRequest())
            fail("should throw")
        } catch let error as VisualGenerationError {
            if case .notConfigured(let id) = error {
                expect(id == "tencent", "AuthFailure should map to notConfigured")
            } else {
                fail("expected notConfigured, got \(error)")
            }
        }

        _ = provider.deleteCredentials()
    }

    // MARK: - Config Store

    func apiProviderConfigStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = APIProviderConfigStore(defaults: defaults)
        var config = APIProviderConfig.default
        config.aliyunModel = "custom-model"
        config.tencentRegion = "ap-shanghai"
        store.save(config)

        let loaded = store.load()
        expect(loaded.aliyunModel == "custom-model", "should load saved aliyun model")
        expect(loaded.tencentRegion == "ap-shanghai", "should load saved tencent region")
        expect(loaded.siliconFlowModel == APIProviderConfig.default.siliconFlowModel, "other fields should keep defaults")
    }

    func apiProviderConfigStoreReturnsDefault() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = APIProviderConfigStore(defaults: defaults)
        let config = store.load()
        expect(config == APIProviderConfig.default, "should return default config when nothing saved")
    }
}

// MARK: - Test Doubles

private final class FakeHTTPClient: APIProviderHTTPExecuting, @unchecked Sendable {
    var stubResponse = APIProviderHTTPResponse(statusCode: 200, data: Data())
    var stubDownloadData = Data()
    private var _lastRequest: URLRequest?
    var lastRequest: URLRequest? { _lastRequest }

    func execute(_ request: URLRequest) async throws -> APIProviderHTTPResponse {
        _lastRequest = request
        return stubResponse
    }

    func downloadData(from url: URL) async throws -> Data {
        stubDownloadData
    }
}

private final class FakeAPIProviderConfigStore: APIProviderConfigStoring, @unchecked Sendable {
    private var _config: APIProviderConfig
    init(config: APIProviderConfig = .default) { _config = config }
    func load() -> APIProviderConfig { _config }
    func save(_ config: APIProviderConfig) { _config = config }
}
