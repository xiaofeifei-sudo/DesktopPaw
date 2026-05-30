import Foundation

public enum AIChatRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
    case system
}

public struct AIChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let role: AIChatRole
    public let content: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        role: AIChatRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public struct AIChatContext: Sendable, Equatable {
    public var systemPrompt: String
    public var temperature: Double?
    public var maxTokens: Int?

    public init(
        systemPrompt: String = "",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct AIChatMessageChunk: Sendable, Equatable {
    public let content: String
    public let isFinished: Bool

    public init(content: String, isFinished: Bool = false) {
        self.content = content
        self.isFinished = isFinished
    }
}

public protocol AIProviding: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var isConfigured: Bool { get }

    func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage
    func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error>
    func estimateTokenCount(for text: String) -> Int
}

public final class HTTPAIProvider: AIProviding, @unchecked Sendable {
    public let providerId: String
    public let displayName: String
    public let config: AIProviderConfig
    private let keychainStore: KeychainStore

    public var isConfigured: Bool {
        keychainStore.loadAPIKey(for: providerId) != nil
    }

    public init(
        providerId: String = "http-openai",
        displayName: String = "OpenAI Compatible",
        config: AIProviderConfig,
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.config = config
        self.keychainStore = keychainStore
    }

    public func saveAPIKey(_ key: String) throws {
        guard keychainStore.saveAPIKey(key, for: providerId) else {
            throw AIProviderError.apiKeySaveFailed("Keychain write failed")
        }
    }

    public func deleteAPIKey() -> Bool {
        keychainStore.deleteAPIKey(for: providerId)
    }

    public func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        guard let apiKey = keychainStore.loadAPIKey(for: providerId) else {
            throw AIProviderError.apiKeyNotFound
        }

        let request = try buildRequest(messages: messages, context: context, apiKey: apiKey, stream: false)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }

        return try parseResponse(data: data, response: response)
    }

    public func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        guard let apiKey = keychainStore.loadAPIKey(for: providerId) else {
            return AsyncThrowingStream { $0.finish(throwing: AIProviderError.apiKeyNotFound) }
        }

        let request: URLRequest
        do {
            request = try buildRequest(messages: messages, context: context, apiKey: apiKey, stream: true)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIProviderError.invalidResponse)
                        return
                    }
                    if httpResponse.statusCode != 200 {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        continuation.finish(throwing: AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(body)"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = parseSSEChunk(data) else { continue }
                        continuation.yield(chunk)
                    }
                    continuation.yield(AIChatMessageChunk(content: "", isFinished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func estimateTokenCount(for text: String) -> Int {
        max(1, text.count / 4)
    }

    private func buildRequest(
        messages: [AIChatMessage],
        context: AIChatContext,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        let endpointURL = Self.resolveEndpoint(base: config.endpoint, path: "/chat/completions")
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var bodyMessages: [[String: String]] = []
        if !context.systemPrompt.isEmpty {
            bodyMessages.append(["role": "system", "content": context.systemPrompt])
        }
        for msg in messages {
            bodyMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": bodyMessages,
            "temperature": context.temperature ?? config.temperature,
            "max_tokens": context.maxTokens ?? config.maxTokens,
            "stream": stream
        ]
        if stream {
            body["stream"] = true
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(data: Data, response: URLResponse) throws -> AIChatMessage {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw AIProviderError.rateLimited
        }
        if httpResponse.statusCode == 401 {
            throw AIProviderError.apiError("Invalid API key")
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: String],
              let content = message["content"] else {
            throw AIProviderError.invalidResponse
        }
        return AIChatMessage(role: .assistant, content: content)
    }

    private func parseSSEChunk(_ data: Data) -> AIChatMessageChunk? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: String],
              let content = delta["content"] else {
            return nil
        }
        return AIChatMessageChunk(content: content)
    }

    private func mapURLError(_ error: URLError) -> AIProviderError {
        switch error.code {
        case .timedOut: .timeout
        case .notConnectedToInternet, .networkConnectionLost: .networkError(error.localizedDescription)
        default: .networkError(error.localizedDescription)
        }
    }

    private static func resolveEndpoint(base: URL, path: String) -> URL {
        let pathString = base.path.hasSuffix(path) ? base : URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)!
        print("[AI] Request URL: \(pathString)")
        return pathString
    }
}

public final class AnthropicAIProvider: AIProviding, @unchecked Sendable {
    public let providerId: String
    public let displayName: String
    public let config: AIProviderConfig
    private let keychainStore: KeychainStore

    public var isConfigured: Bool {
        keychainStore.loadAPIKey(for: providerId) != nil
    }

    public init(
        providerId: String = "anthropic",
        displayName: String = "Anthropic",
        config: AIProviderConfig,
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.config = config
        self.keychainStore = keychainStore
    }

    public func saveAPIKey(_ key: String) throws {
        guard keychainStore.saveAPIKey(key, for: providerId) else {
            throw AIProviderError.apiKeySaveFailed("Keychain write failed")
        }
    }

    public func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        guard let apiKey = keychainStore.loadAPIKey(for: providerId) else {
            throw AIProviderError.apiKeyNotFound
        }

        let request = try buildRequest(messages: messages, context: context, apiKey: apiKey)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }

        return try parseResponse(data: data, response: response)
    }

    public func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        guard let apiKey = keychainStore.loadAPIKey(for: providerId) else {
            return AsyncThrowingStream { $0.finish(throwing: AIProviderError.apiKeyNotFound) }
        }

        let request: URLRequest
        do {
            request = try buildRequest(messages: messages, context: context, apiKey: apiKey)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIProviderError.invalidResponse)
                        return
                    }
                    if httpResponse.statusCode != 200 {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        continuation.finish(throwing: AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(body)"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = parseSSEChunk(data) else { continue }
                        continuation.yield(chunk)
                    }
                    continuation.yield(AIChatMessageChunk(content: "", isFinished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func estimateTokenCount(for text: String) -> Int {
        max(1, text.count / 4)
    }

    private func buildRequest(
        messages: [AIChatMessage],
        context: AIChatContext,
        apiKey: String
    ) throws -> URLRequest {
        let endpointURL = Self.resolveEndpoint(base: config.endpoint, path: "/v1/messages")
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var bodyMessages: [[String: String]] = []
        var systemPrompt: String?
        for msg in messages {
            if msg.role == .system {
                systemPrompt = msg.content
            } else {
                bodyMessages.append(["role": msg.role.rawValue, "content": msg.content])
            }
        }
        if !context.systemPrompt.isEmpty {
            systemPrompt = context.systemPrompt
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": bodyMessages,
            "max_tokens": context.maxTokens ?? config.maxTokens
        ]
        if let systemPrompt {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(data: Data, response: URLResponse) throws -> AIChatMessage {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw AIProviderError.rateLimited
        }
        if httpResponse.statusCode == 401 {
            throw AIProviderError.apiError("Invalid API key")
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
            throw AIProviderError.invalidResponse
        }
        return AIChatMessage(role: .assistant, content: text)
    }

    private func parseSSEChunk(_ data: Data) -> AIChatMessageChunk? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = json["delta"] as? [String: Any],
              let text = delta["text"] as? String else {
            return nil
        }
        return AIChatMessageChunk(content: text)
    }

    private func mapURLError(_ error: URLError) -> AIProviderError {
        switch error.code {
        case .timedOut: .timeout
        case .notConnectedToInternet, .networkConnectionLost: .networkError(error.localizedDescription)
        default: .networkError(error.localizedDescription)
        }
    }

    private static func resolveEndpoint(base: URL, path: String) -> URL {
        if base.path.hasSuffix(path) { return base }
        let trimmed = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed + path)!
    }
}

public final class MockAIProvider: AIProviding, @unchecked Sendable {
    public let providerId = "mock"
    public let displayName = "Mock Provider"
    public var isConfigured = true

    public var stubbedResponse: String
    public private(set) var completeCallCount = 0
    public private(set) var lastMessages: [AIChatMessage]?
    public private(set) var lastContext: AIChatContext?

    public init(stubbedResponse: String = "mock response") {
        self.stubbedResponse = stubbedResponse
    }

    public func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        completeCallCount += 1
        lastMessages = messages
        lastContext = context
        return AIChatMessage(role: .assistant, content: stubbedResponse)
    }

    public func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        let response = stubbedResponse
        return AsyncThrowingStream { continuation in
            continuation.yield(AIChatMessageChunk(content: response, isFinished: true))
            continuation.finish()
        }
    }

    public func estimateTokenCount(for text: String) -> Int {
        max(1, text.count / 4)
    }
}
