import Foundation
import DesktopPet

@MainActor
func runStaticPhraseLibraryTests() {
    let tests = StaticPhraseLibraryTests()
    tests.allTypesHavePhrases()
    tests.phraseCountPerType()
    tests.allTypesHaveOptions()
    tests.optionCountPerType()
    tests.everyTypeHasPrimaryOption()
    tests.everyTypeHasNoneOption()
}

@MainActor
private struct StaticPhraseLibraryTests {
    func allTypesHavePhrases() {
        for type in BubbleType.allCases {
            let phrases = StaticPhraseLibrary.phrases[type]
            expect(phrases != nil, "\(type.rawValue) should have phrases")
        }
    }

    func phraseCountPerType() {
        for type in BubbleType.allCases {
            let phrases = StaticPhraseLibrary.phrases[type]!
            expect(phrases.count >= 5 && phrases.count <= 10,
                   "\(type.rawValue) should have 5-10 phrases, got \(phrases.count)")
        }
    }

    func allTypesHaveOptions() {
        for type in BubbleType.allCases {
            let options = StaticPhraseLibrary.defaultOptions[type]
            expect(options != nil, "\(type.rawValue) should have default options")
        }
    }

    func optionCountPerType() {
        for type in BubbleType.allCases {
            let options = StaticPhraseLibrary.defaultOptions[type]!
            expect(options.count >= 2 && options.count <= 3,
                   "\(type.rawValue) should have 2-3 options, got \(options.count)")
        }
    }

    func everyTypeHasPrimaryOption() {
        for type in BubbleType.allCases {
            let options = StaticPhraseLibrary.defaultOptions[type]!
            let hasPrimary = options.contains { $0.isPrimary }
            expect(hasPrimary, "\(type.rawValue) should have a primary option")
        }
    }

    func everyTypeHasNoneOption() {
        for type in BubbleType.allCases {
            let options = StaticPhraseLibrary.defaultOptions[type]!
            let hasNone = options.contains { $0.effect == .none }
            expect(hasNone, "\(type.rawValue) should have a none-effect option")
        }
    }
}

@MainActor
func runInteractiveBubbleContentGeneratorTests() async {
    let tests = ContentGeneratorTests()
    await tests.generateReturnsNilWhenNoProvider()
    tests.generateFallbackReturnsValidBubble()
    tests.hungerHighSelectsNeedExpression()
    tests.energyLowSelectsNeedExpression()
    tests.moodLowSelectsEmotionSharing()
    tests.consecutiveNoResponseSelectsLightType()
    tests.defaultSelectsFromAllTypes()
    tests.dedupAvoidsRecentTexts()
    tests.dedupFallsBackWhenAllUsed()
    tests.expirySetFromWaitDuration()
}

@MainActor
func runInteractiveBubbleContentGeneratorAITests() async {
    let tests = ContentGeneratorAITests()
    await tests.generateReturnsBubbleWhenAIConfigured()
    await tests.generateReturnsNilWhenAIReturnsInvalidJSON()
    await tests.generateReturnsNilWhenTextTooShort()
    await tests.generateReturnsNilWhenTextTooLong()
    await tests.generateReturnsNilWhenTooManyOptions()
    await tests.generateReturnsNilWhenTooFewOptions()
    await tests.generateReturnsNilWhenNoPositiveOption()
    await tests.generateReturnsNilWhenNoNoneOption()
    await tests.generateReturnsNilWhenInvalidEffect()
    await tests.generateReturnsNilWhenAIProviderThrows()
    await tests.generateReturnsNilWhenSafetyBlocks()
    await tests.generateRetriesOnSimilarText()
    await tests.generateReturnsNilWhenBothAttemptsSimilar()
    await tests.generateReturnsNilWhenUnconfiguredProvider()
    await tests.generateHandlesJSONWrappedInMarkdown()
    await tests.generateHandlesExtraWhitespace()
    await tests.promptContainsContextInfo()
    await tests.systemPromptRestrictsCaringAtAcquaintance()
}

// MARK: - Fallback Tests

@MainActor
private struct ContentGeneratorTests {
    private let defaultWait: TimeInterval = 15

    private func makeContext(
        hunger: Double = 0.2,
        mood: Double = 0.5,
        energy: Double = 0.5,
        recentTexts: [String] = [],
        consecutiveNoResponse: Int = 0
    ) -> BubbleContext {
        let state = PetRuntimeState(
            currentState: .idle,
            mood: mood,
            hunger: hunger,
            energy: energy,
            lastInteractionAt: Date(),
            isDragging: false,
            scale: 1.0
        )
        return BubbleContext(
            petId: "test",
            petNickname: "小宠",
            userNickname: "主人",
            runtimeState: state,
            relationshipLevel: .familiar,
            recentBubbleTexts: recentTexts,
            consecutiveNoResponse: consecutiveNoResponse
        )
    }

    func generateReturnsNilWhenNoProvider() async {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext()
        let result = await gen.generate(context: context)
        expect(result == nil, "generate should return nil without AI provider")
    }

    func generateFallbackReturnsValidBubble() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext()
        let bubble = gen.generateFallback(context: context)
        expect(!bubble.text.isEmpty, "bubble text should not be empty")
        expect(bubble.options.count >= 2, "bubble should have at least 2 options")
        expect(BubbleType.allCases.contains(bubble.type),
               "bubble type should be a valid BubbleType")
        let expectedOptions = StaticPhraseLibrary.defaultOptions[bubble.type]!
        expect(bubble.options == expectedOptions, "bubble options should match the type's default options")
    }

    func hungerHighSelectsNeedExpression() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext(hunger: 0.8)
        let selected = selectTypeViaGenerator(gen, context: context)
        expect(selected == .needExpression, "high hunger should select needExpression")
    }

    func energyLowSelectsNeedExpression() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext(energy: 0.2)
        let selected = selectTypeViaGenerator(gen, context: context)
        expect(selected == .needExpression, "low energy should select needExpression")
    }

    func moodLowSelectsEmotionSharing() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext(mood: 0.2)
        let selected = selectTypeViaGenerator(gen, context: context)
        expect(selected == .emotionSharing, "low mood should select emotionSharing")
    }

    func consecutiveNoResponseSelectsLightType() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext(consecutiveNoResponse: 3)
        let lightTypes: [BubbleType] = [.randomTopic, .curiousQuestion, .gameInvitation]

        var foundLight = false
        for _ in 0..<20 {
            let selected = selectTypeViaGenerator(gen, context: context)
            if lightTypes.contains(selected) { foundLight = true; break }
        }
        expect(foundLight, "high consecutiveNoResponse should select a light type")
    }

    func defaultSelectsFromAllTypes() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let context = makeContext()
        var seen = Set<BubbleType>()
        for _ in 0..<60 {
            let selected = selectTypeViaGenerator(gen, context: context)
            seen.insert(selected)
        }
        expect(seen.count >= 3, "default random should select multiple types over many runs, got \(seen.count)")
    }

    func dedupAvoidsRecentTexts() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let allPhrases = StaticPhraseLibrary.phrases[.needExpression]!
        let recentTexts = Array(allPhrases.dropLast())
        let context = makeContext(hunger: 0.8, recentTexts: recentTexts)

        let bubble = gen.generateFallback(context: context)
        expect(bubble.text == allPhrases.last!,
               "should pick the only non-recent phrase")
    }

    func dedupFallsBackWhenAllUsed() {
        let gen = InteractiveBubbleContentGenerator(waitDuration: defaultWait)
        let allPhrases = StaticPhraseLibrary.phrases[.needExpression]!
        let context = makeContext(hunger: 0.8, recentTexts: allPhrases)

        let bubble = gen.generateFallback(context: context)
        expect(allPhrases.contains(bubble.text),
               "should still pick from all phrases when all are recent")
    }

    func expirySetFromWaitDuration() {
        let waitDuration: TimeInterval = 20
        let gen = InteractiveBubbleContentGenerator(waitDuration: waitDuration)
        let context = makeContext()

        let bubble = gen.generateFallback(context: context)
        let diff = bubble.expiresAt.timeIntervalSince(bubble.createdAt)
        expect(diff == waitDuration, "expiry should equal waitDuration, got \(diff)")
    }

    private func selectTypeViaGenerator(
        _ gen: InteractiveBubbleContentGenerator,
        context: BubbleContext
    ) -> BubbleType {
        gen.selectType(for: context)
    }
}

// MARK: - AI Generation Tests

@MainActor
private struct ContentGeneratorAITests {
    private let defaultWait: TimeInterval = 15

    private static let validJSON = """
    {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"🤗","label":"摸摸你","effect":"pet","isPrimary":false},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
    """

    private func makeContext(
        hunger: Double = 0.2,
        mood: Double = 0.5,
        energy: Double = 0.5,
        relationshipLevel: RelationshipLevel = .familiar,
        recentTexts: [String] = [],
        consecutiveNoResponse: Int = 0,
        memorySnippets: [String] = []
    ) -> BubbleContext {
        let state = PetRuntimeState(
            currentState: .idle,
            mood: mood,
            hunger: hunger,
            energy: energy,
            lastInteractionAt: Date(),
            isDragging: false,
            scale: 1.0
        )
        return BubbleContext(
            petId: "test",
            petNickname: "小宠",
            userNickname: "主人",
            runtimeState: state,
            relationshipLevel: relationshipLevel,
            recentBubbleTexts: recentTexts,
            consecutiveNoResponse: consecutiveNoResponse,
            memorySnippets: memorySnippets
        )
    }

    private func awaitGenerate(
        provider: AIProviding,
        safetyService: AISafetyServicing? = nil,
        context: BubbleContext
    ) async -> InteractiveBubble? {
        let gen = InteractiveBubbleContentGenerator(
            waitDuration: defaultWait,
            aiProvider: provider,
            safetyService: safetyService
        )
        return await gen.generate(context: context)
    }

    func generateReturnsBubbleWhenAIConfigured() async {
        let provider = MockAIProvider(stubbedResponse: Self.validJSON)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result != nil, "should return bubble from AI")
        expect(result!.text == "好饿呀...能给我弄点吃的吗？", "text should match AI response")
        expect(result!.type == .needExpression, "type should match AI response")
        expect(result!.options.count == 3, "should have 3 options")
        expect(result!.options[0].isPrimary == true, "first option should be primary")
        expect(result!.options[0].effect == .feed, "first option should be feed")
        expect(result!.options[2].effect == .none, "last option should be none")
    }

    func generateReturnsNilWhenAIReturnsInvalidJSON() async {
        let provider = MockAIProvider(stubbedResponse: "this is not json")
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for invalid JSON")
    }

    func generateReturnsNilWhenTextTooShort() async {
        let json = """
        {"text":"短","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for text shorter than 15 chars")
    }

    func generateReturnsNilWhenTextTooLong() async {
        let longText = String(repeating: "这是一段很长的文字", count: 5)
        let json = """
        {"text":"\(longText)","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for text longer than 40 chars")
    }

    func generateReturnsNilWhenTooManyOptions() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"🤗","label":"摸摸你","effect":"pet","isPrimary":false},{"emoji":"🎮","label":"玩一下","effect":"play","isPrimary":false},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for more than 3 options")
    }

    func generateReturnsNilWhenTooFewOptions() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for fewer than 2 options")
    }

    func generateReturnsNilWhenNoPositiveOption() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":true},{"emoji":"💬","label":"聊聊","effect":"chat","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil when no positive option (feed/play/pet/positiveResponse)")
    }

    func generateReturnsNilWhenNoNoneOption() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"🤗","label":"摸摸你","effect":"pet","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil when no none-effect option")
    }

    func generateReturnsNilWhenInvalidEffect() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"invalidEffect","isPrimary":true},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil for invalid effect type")
    }

    func generateReturnsNilWhenAIProviderThrows() async {
        let provider = ThrowingAIProvider()
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil when AI provider throws")
    }

    func generateReturnsNilWhenSafetyBlocks() async {
        let safety = BlockingSafetyService()
        let provider = MockAIProvider(stubbedResponse: Self.validJSON)
        let result = await awaitGenerate(provider: provider, safetyService: safety, context: makeContext())
        expect(result == nil, "should return nil when safety service blocks content")
    }

    func generateRetriesOnSimilarText() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let context = makeContext(recentTexts: ["好饿呀...能给我弄点吃的吗？"])
        let result = await awaitGenerate(provider: provider, context: context)
        expect(provider.completeCallCount == 2, "should retry once when text is similar to recent, got \(provider.completeCallCount)")
    }

    func generateReturnsNilWhenBothAttemptsSimilar() async {
        let json = """
        {"text":"好饿呀...能给我弄点吃的吗？","type":"needExpression","options":[{"emoji":"🍪","label":"好的呀","effect":"feed","isPrimary":true},{"emoji":"⏳","label":"等一下","effect":"none","isPrimary":false}]}
        """
        let provider = MockAIProvider(stubbedResponse: json)
        let context = makeContext(recentTexts: ["好饿呀...能给我弄点吃的吗？"])
        let result = await awaitGenerate(provider: provider, context: context)
        expect(result == nil, "should return nil when both attempts produce similar text")
    }

    func generateReturnsNilWhenUnconfiguredProvider() async {
        let provider = MockAIProvider()
        provider.isConfigured = false
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result == nil, "should return nil when provider is not configured")
    }

    func generateHandlesJSONWrappedInMarkdown() async {
        let wrapped = "```json\n\(Self.validJSON)\n```"
        let provider = MockAIProvider(stubbedResponse: wrapped)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result != nil, "should parse JSON wrapped in markdown code block")
    }

    func generateHandlesExtraWhitespace() async {
        let padded = "  \n  \(Self.validJSON)  \n  "
        let provider = MockAIProvider(stubbedResponse: padded)
        let result = await awaitGenerate(provider: provider, context: makeContext())
        expect(result != nil, "should parse JSON with extra whitespace")
    }

    func promptContainsContextInfo() async {
        let provider = MockAIProvider(stubbedResponse: Self.validJSON)
        let context = makeContext(
            hunger: 0.8,
            mood: 0.6,
            energy: 0.4,
            recentTexts: ["你好呀"],
            consecutiveNoResponse: 0,
            memorySnippets: ["主人喜欢咖啡"]
        )
        _ = await awaitGenerate(provider: provider, context: context)

        let userPrompt = provider.lastMessages?.first?.content ?? ""
        expect(userPrompt.contains("小宠"), "prompt should contain pet nickname")
        expect(userPrompt.contains("主人"), "prompt should contain user nickname")
        expect(userPrompt.contains("80%"), "prompt should contain hunger percentage")
        expect(userPrompt.contains("你好呀"), "prompt should contain recent bubble text")
        expect(userPrompt.contains("主人喜欢咖啡"), "prompt should contain memory snippet")

        let systemPrompt = provider.lastContext?.systemPrompt ?? ""
        expect(systemPrompt.contains("feed"), "system prompt should list effect types")
        expect(systemPrompt.contains("15-40"), "system prompt should specify text length")
    }

    func systemPromptRestrictsCaringAtAcquaintance() async {
        let provider = MockAIProvider(stubbedResponse: Self.validJSON)
        let context = makeContext(relationshipLevel: .acquaintance)
        _ = await awaitGenerate(provider: provider, context: context)
        let systemPrompt = provider.lastContext?.systemPrompt ?? ""
        expect(systemPrompt.contains("不要使用 caringOwner"), "system prompt should restrict caringOwner at acquaintance level")
    }
}

// MARK: - Test Helpers

private final class ThrowingAIProvider: AIProviding, @unchecked Sendable {
    let providerId = "throwing"
    let displayName = "Throwing Provider"
    let isConfigured = true

    func complete(messages: [AIChatMessage], context: AIChatContext) async throws -> AIChatMessage {
        throw AIProviderError.networkError("test error")
    }

    func completeStreaming(messages: [AIChatMessage], context: AIChatContext) -> AsyncThrowingStream<AIChatMessageChunk, Error> {
        AsyncThrowingStream { $0.finish(throwing: AIProviderError.networkError("test error")) }
    }

    func estimateTokenCount(for text: String) -> Int { 0 }
}

private final class BlockingSafetyService: AISafetyServicing, @unchecked Sendable {
    func classifyRisk(content: String) -> AIRiskLevel { .high }
    func shouldBlock(content: String) -> Bool { true }
    func safeResponse(for riskLevel: AIRiskLevel, category: AISafetyCategory?) -> String { "安全回复" }
    func validatePromptSafety(_ prompt: String) -> AISafetyCheckResult {
        AISafetyCheckResult(riskLevel: .high, shouldBlock: true, violatedCategory: nil)
    }
}
