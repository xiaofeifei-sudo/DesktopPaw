import Foundation

public struct AIChatContextBuilder: Sendable {
    private let personalityEngine: AIPersonalityEngineProtocol
    private let personalityProfileProvider: @Sendable () -> AIPersonalityProfile

    public init(
        personalityEngine: AIPersonalityEngineProtocol,
        personalityProfile: AIPersonalityProfile = .gentle
    ) {
        self.personalityEngine = personalityEngine
        self.personalityProfileProvider = { personalityProfile }
    }

    public init(
        personalityEngine: AIPersonalityEngineProtocol,
        personalityProfileProvider: @escaping @Sendable () -> AIPersonalityProfile
    ) {
        self.personalityEngine = personalityEngine
        self.personalityProfileProvider = personalityProfileProvider
    }

    public func build(
        context: CompanionContext,
        memoryContext: String?
    ) -> AIChatContext {
        let systemPrompt = personalityEngine.buildSystemPrompt(
            profile: personalityProfileProvider(),
            context: context,
            memoryContext: memoryContext
        )
        return AIChatContext(
            systemPrompt: systemPrompt,
            temperature: nil,
            maxTokens: nil
        )
    }
}
