import Foundation

public final class AIChatEngine: AIChatEngining, @unchecked Sendable {
    private var provider: AIProviding
    private let memoryStore: AIMemoryStoring
    private let safetyService: AISafetyServicing
    private let personalityEngine: AIPersonalityEngineProtocol
    private let contextBuilder: AIChatContextBuilder
    private let memoryPromptComposer: MemoryPromptComposing
    private let emotionalModelStore: EmotionalModelStoring?
    private let visualActionParser: AIVisualActionParsing?

    private var sessions: [String: AIChatSession] = [:]

    public init(
        provider: AIProviding,
        memoryStore: AIMemoryStoring,
        safetyService: AISafetyServicing,
        personalityEngine: AIPersonalityEngineProtocol,
        memoryPromptComposer: MemoryPromptComposing = MemoryPromptComposer(),
        emotionalModelStore: EmotionalModelStoring? = nil,
        personalityProfile: AIPersonalityProfile = .gentle,
        personalityProfileProvider: (@Sendable () -> AIPersonalityProfile)? = nil,
        visualActionParser: AIVisualActionParsing? = nil
    ) {
        self.provider = provider
        self.memoryStore = memoryStore
        self.safetyService = safetyService
        self.personalityEngine = personalityEngine
        self.memoryPromptComposer = memoryPromptComposer
        self.emotionalModelStore = emotionalModelStore
        self.visualActionParser = visualActionParser
        if let personalityProfileProvider {
            self.contextBuilder = AIChatContextBuilder(
                personalityEngine: personalityEngine,
                personalityProfileProvider: personalityProfileProvider
            )
        } else {
            self.contextBuilder = AIChatContextBuilder(
                personalityEngine: personalityEngine,
                personalityProfile: personalityProfile
            )
        }
    }

    public func sendMessage(_ text: String, petId: String) async throws -> AIChatResponse {
        let inputSafety = safetyService.validatePromptSafety(text)
        if inputSafety.shouldBlock {
            let safeText = inputSafety.safeResponseText ?? safetyService.safeResponse(
                for: inputSafety.riskLevel, category: inputSafety.violatedCategory
            )
            let safeMessage = AIChatMessage(role: .assistant, content: safeText)
            return AIChatResponse(
                message: safeMessage,
                bubbleText: truncateForBubble(safeText),
                panelText: safeText,
                safetyLevel: inputSafety.riskLevel,
                memoryUpdates: []
            )
        }

        var session = getOrCreateSession(petId: petId)
        let userMessage = AIChatMessage(role: .user, content: text)
        session.messages.append(userMessage)

        let memories = memoryStore.loadAll(petId: petId)
        let emotionalModel = try? emotionalModelStore?.loadModel(petId: petId)
        let memoryResult = memoryPromptComposer.composeMemoryContext(
            memories: memories,
            emotionalModel: emotionalModel
        )
        let companionContext = CompanionContext(
            petId: petId,
            petDisplayName: "桌宠",
            petNickname: nil,
            userNickname: nil,
            runtimeState: .defaultState(),
            relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
            preferences: CompanionPreferences(),
            timeSlots: [],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )

        let aiContext = contextBuilder.build(context: companionContext, memoryContext: memoryResult.text)
        let contextMessages = session.contextMessages()
            .filter { $0.role != .system }
            .map { AIChatMessage(role: $0.role, content: $0.content) }

        let aiResponse: AIChatMessage
        do {
            let currentProvider = provider
            print("[AI] Sending to provider: \(currentProvider.providerId), isConfigured: \(currentProvider.isConfigured)")
            aiResponse = try await currentProvider.complete(messages: contextMessages, context: aiContext)
        } catch {
            print("[AI] Provider error: \(error)")
            DesktopPetLog.aiCompanion.error("AI provider error: \(error)")
            let fallbackText = "暂时无法回复"
            let fallbackMessage = AIChatMessage(role: .assistant, content: fallbackText)
            session.messages.append(fallbackMessage)
            sessions[petId] = session
            return AIChatResponse(
                message: fallbackMessage,
                bubbleText: fallbackText,
                panelText: fallbackText,
                safetyLevel: .safe,
                memoryUpdates: []
            )
        }

        let rawContent = aiResponse.content
        let cleanedContent = Self.stripThinkingTags(rawContent)

        let parseResult: AIVisualParseResult
        if let parser = visualActionParser {
            parseResult = parser.parse(from: cleanedContent, petId: petId, source: .chat)
        } else {
            parseResult = AIVisualParseResult(cleanedResponse: cleanedContent, candidates: [], parseWarnings: [])
        }

        let displayContent = parseResult.cleanedResponse
        let cleanedMessage = AIChatMessage(role: .assistant, content: displayContent)

        let outputSafety = safetyService.validatePromptSafety(displayContent)
        if outputSafety.shouldBlock {
            let safeText = outputSafety.safeResponseText ?? safetyService.safeResponse(
                for: outputSafety.riskLevel, category: outputSafety.violatedCategory
            )
            let safeMessage = AIChatMessage(role: .assistant, content: safeText)
            session.messages.append(safeMessage)
            sessions[petId] = session
            return AIChatResponse(
                message: safeMessage,
                bubbleText: truncateForBubble(safeText),
                panelText: safeText,
                safetyLevel: outputSafety.riskLevel,
                memoryUpdates: []
            )
        }

        session.messages.append(cleanedMessage)
        sessions[petId] = session

        let bubbleText = AIPersonalityEngine.parseBubbleText(from: displayContent)
            ?? truncateForBubble(displayContent)
        let panelText = AIPersonalityEngine.parsePanelText(from: displayContent)
            ?? displayContent

        var memoryUpdates: [AIMemory] = []
        if let memoryText = AIPersonalityEngine.parseMemoryUpdate(from: displayContent) {
            let memory = AIMemory(
                petId: petId,
                category: .interaction,
                content: memoryText,
                source: .aiExtracted
            )
            do {
                try memoryStore.add(memory, petId: petId)
                memoryUpdates.append(memory)
            } catch {
                DesktopPetLog.aiCompanion.warning("Failed to save extracted memory: \(error.localizedDescription)")
            }
        }

        for id in memoryResult.usedMemoryIds {
            try? memoryStore.incrementAccessCount(id: id, petId: petId)
        }

        for warning in parseResult.parseWarnings {
            DesktopPetLog.aiCompanion.warning("Visual action parse warning: \(warning)")
        }

        return AIChatResponse(
            message: cleanedMessage,
            bubbleText: bubbleText,
            panelText: panelText,
            safetyLevel: outputSafety.riskLevel,
            memoryUpdates: memoryUpdates,
            visualActionCandidates: parseResult.candidates
        )
    }

    public func sendMessageStreaming(_ text: String, petId: String) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        let inputSafety = safetyService.validatePromptSafety(text)
        if inputSafety.shouldBlock {
            let safeText = inputSafety.safeResponseText ?? safetyService.safeResponse(
                for: inputSafety.riskLevel, category: inputSafety.violatedCategory
            )
            let safeMessage = AIChatMessage(role: .assistant, content: safeText)
            let response = AIChatResponse(
                message: safeMessage,
                bubbleText: truncateForBubble(safeText),
                panelText: safeText,
                safetyLevel: inputSafety.riskLevel,
                memoryUpdates: []
            )
            return AsyncThrowingStream { $0.yield(.completed(response)); $0.finish() }
        }

        var session = getOrCreateSession(petId: petId)
        let userMessage = AIChatMessage(role: .user, content: text)
        session.messages.append(userMessage)
        sessions[petId] = session

        let memories = memoryStore.loadAll(petId: petId)
        let emotionalModel = try? emotionalModelStore?.loadModel(petId: petId)
        let memoryResult = memoryPromptComposer.composeMemoryContext(
            memories: memories,
            emotionalModel: emotionalModel
        )
        let companionContext = CompanionContext(
            petId: petId,
            petDisplayName: "桌宠",
            petNickname: nil,
            userNickname: nil,
            runtimeState: .defaultState(),
            relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
            preferences: CompanionPreferences(),
            timeSlots: [],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )

        let aiContext = contextBuilder.build(context: companionContext, memoryContext: memoryResult.text)
        let contextMessages = session.contextMessages()
            .filter { $0.role != .system }
            .map { AIChatMessage(role: $0.role, content: $0.content) }

        let currentProvider = provider
        let engine = self

        return AsyncThrowingStream { continuation in
            let task = Task {
                var accumulated = ""
                var isInThinkingBlock = false

                do {
                    let stream = currentProvider.completeStreaming(messages: contextMessages, context: aiContext)
                    for try await chunk in stream {
                        if chunk.isFinished { break }

                        let token = chunk.content
                        let combined = accumulated + token

                        if combined.contains("<think") || combined.contains("<reasoning") || combined.contains("<reflection") {
                            isInThinkingBlock = true
                        }
                        if isInThinkingBlock {
                            if combined.contains("</think") || combined.contains("</reasoning") || combined.contains("</reflection") {
                                isInThinkingBlock = false
                                let cleaned = Self.stripThinkingTags(combined)
                                accumulated = cleaned
                            } else {
                                accumulated = combined
                                continue
                            }
                        } else {
                            accumulated = combined
                            let filteredToken = Self.filterVisualActionFragment(token)
                            if !filteredToken.isEmpty {
                                continuation.yield(.token(filteredToken))
                            }
                        }
                    }

                    let cleanedContent = Self.stripThinkingTags(accumulated)

                    let parseResult: AIVisualParseResult
                    if let parser = engine.visualActionParser {
                        parseResult = parser.parse(from: cleanedContent, petId: petId, source: .chat)
                    } else {
                        parseResult = AIVisualParseResult(cleanedResponse: cleanedContent, candidates: [], parseWarnings: [])
                    }

                    let displayContent = parseResult.cleanedResponse
                    let cleanedMessage = AIChatMessage(role: .assistant, content: displayContent)

                    let outputSafety = engine.safetyService.validatePromptSafety(displayContent)
                    let finalMessage: AIChatMessage
                    if outputSafety.shouldBlock {
                        let safeText = outputSafety.safeResponseText ?? engine.safetyService.safeResponse(
                            for: outputSafety.riskLevel, category: outputSafety.violatedCategory
                        )
                        finalMessage = AIChatMessage(role: .assistant, content: safeText)
                    } else {
                        finalMessage = cleanedMessage
                    }

                    var updatedSession = engine.getOrCreateSession(petId: petId)
                    updatedSession.messages.append(finalMessage)
                    engine.sessions[petId] = updatedSession

                    let bubbleText = AIPersonalityEngine.parseBubbleText(from: finalMessage.content)
                        ?? engine.truncateForBubble(finalMessage.content)
                    let panelText = AIPersonalityEngine.parsePanelText(from: finalMessage.content)
                        ?? finalMessage.content

                    var memoryUpdates: [AIMemory] = []
                    if let memoryText = AIPersonalityEngine.parseMemoryUpdate(from: finalMessage.content) {
                        let memory = AIMemory(
                            petId: petId,
                            category: .interaction,
                            content: memoryText,
                            source: .aiExtracted
                        )
                        try? engine.memoryStore.add(memory, petId: petId)
                        memoryUpdates.append(memory)
                    }

                    for id in memoryResult.usedMemoryIds {
                        try? engine.memoryStore.incrementAccessCount(id: id, petId: petId)
                    }

                    for warning in parseResult.parseWarnings {
                        DesktopPetLog.aiCompanion.warning("Visual action parse warning: \(warning)")
                    }

                    let response = AIChatResponse(
                        message: finalMessage,
                        bubbleText: bubbleText,
                        panelText: panelText,
                        safetyLevel: outputSafety.riskLevel,
                        memoryUpdates: memoryUpdates,
                        visualActionCandidates: parseResult.candidates
                    )
                    continuation.yield(.completed(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func getActiveSession(petId: String) -> AIChatSession? {
        guard let session = sessions[petId], session.isActive else { return nil }
        return session
    }

    public func startSession(petId: String) -> AIChatSession {
        if let existing = sessions[petId], existing.isActive {
            return existing
        }
        let session = AIChatSession(petId: petId)
        sessions[petId] = session
        return session
    }

    public func endSession(petId: String) {
        guard var session = sessions[petId] else { return }
        session.endedAt = Date()
        sessions[petId] = session
    }

    public func getRecentMessages(petId: String, limit: Int) -> [AIChatMessage] {
        guard let session = sessions[petId] else { return [] }
        return Array(session.messages.suffix(limit))
    }

    private func getOrCreateSession(petId: String) -> AIChatSession {
        if let existing = sessions[petId], existing.isActive {
            return existing
        }
        let session = AIChatSession(petId: petId)
        sessions[petId] = session
        return session
    }

    private func truncateForBubble(_ text: String) -> String {
        let limit = 12
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    public func updateProvider(_ newProvider: AIProviding) {
        provider = newProvider
    }

    private static func stripThinkingTags(_ text: String) -> String {
        let pattern = #"<think[\s\S]*?<\/think\s*>|<reasoning[\s\S]*?<\/reasoning\s*>|<reflection[\s\S]*?<\/reflection\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: ""
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func filterVisualActionFragment(_ token: String) -> String {
        if token.contains("[VISUAL_ACTION]") || token.contains("[/VISUAL_ACTION]") {
            return ""
        }
        return token
    }
}
