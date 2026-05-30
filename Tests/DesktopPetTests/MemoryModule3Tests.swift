import Foundation
import DesktopPet

@MainActor
func runMemoryModule3Tests() {
    let tests = MemoryModule3Tests()
    tests.p0ProtectedCategoriesAlwaysInjected()
    tests.p1CategoriesInjectedWhenNotExpired()
    tests.expiredMemoriesExcluded()
    tests.interactionsSortedByScore()
    tests.interactionsLimitedToMaxCount()
    tests.emotionalModelSectionFormatted()
    tests.emotionalModelSectionTopics()
    tests.emotionalModelNilProducesNoRelationshipSection()
    tests.milestoneAndCustomInImportantMemories()
    tests.usedMemoryIdsCorrect()
    tests.tokenEstimatePositive()
    tests.emptyMemoriesProduceEmptyResult()
    tests.onlyNicknameProducesAboutUserOnly()
    tests.multipleMemoriesAggregated()
    tests.resultIsSendable()
    tests.accessCountUsedInInteractionScore()
}

@MainActor
private struct MemoryModule3Tests {
    private let composer = MemoryPromptComposer()

    private func makeMemory(
        category: AIMemoryCategory,
        content: String,
        importance: Double = 0.5,
        accessCount: Int = 0,
        expiresAt: Date? = nil,
        id: String = UUID().uuidString
    ) -> AIMemory {
        AIMemory(
            id: id,
            petId: "test-pet",
            category: category,
            content: content,
            source: .userProvided,
            importance: importance,
            accessCount: accessCount,
            expiresAt: expiresAt
        )
    }

    // MARK: - P0 Protected Categories

    func p0ProtectedCategoriesAlwaysInjected() {
        let nickname = makeMemory(category: .nickname, content: "叫我小明")
        let custom = makeMemory(category: .custom, content: "我的猫叫小橘")
        let milestone = makeMemory(category: .milestone, content: "用户毕业了")

        let result = composer.composeMemoryContext(
            memories: [nickname, custom, milestone],
            emotionalModel: nil
        )

        expect(result.text.contains("小明"), "nickname should always appear")
        expect(result.text.contains("小橘"), "custom should always appear")
        expect(result.text.contains("毕业"), "milestone should always appear")
    }

    // MARK: - P1 Categories

    func p1CategoriesInjectedWhenNotExpired() {
        let preference = makeMemory(category: .preference, content: "喜欢冷色调")
        let routine = makeMemory(category: .routine, content: "晚上9-11点活跃")
        let emotion = makeMemory(category: .emotion, content: "最近压力大")

        let result = composer.composeMemoryContext(
            memories: [preference, routine, emotion],
            emotionalModel: nil
        )

        expect(result.text.contains("冷色调"), "preference should appear")
        expect(result.text.contains("9-11"), "routine should appear")
        expect(result.text.contains("压力大"), "emotion should appear")
    }

    // MARK: - Expired Memories

    func expiredMemoriesExcluded() {
        let expired = makeMemory(
            category: .preference,
            content: "已过期的偏好",
            expiresAt: Date().addingTimeInterval(-86400)
        )
        let active = makeMemory(category: .preference, content: "有效的偏好")

        let result = composer.composeMemoryContext(
            memories: [expired, active],
            emotionalModel: nil
        )

        expect(!result.text.contains("已过期"), "expired memory should be excluded")
        expect(result.text.contains("有效"), "active memory should appear")
        expect(!result.usedMemoryIds.contains(expired.id), "expired memory ID should not be in usedMemoryIds")
        expect(result.usedMemoryIds.contains(active.id), "active memory ID should be in usedMemoryIds")
    }

    // MARK: - P2 Interaction Sorting

    func interactionsSortedByScore() {
        let low = makeMemory(category: .interaction, content: "低分互动", importance: 0.2, accessCount: 1, id: "low")
        let high = makeMemory(category: .interaction, content: "高分互动", importance: 0.9, accessCount: 5, id: "high")
        let mid = makeMemory(category: .interaction, content: "中分互动", importance: 0.5, accessCount: 3, id: "mid")

        let limitedComposer = MemoryPromptComposer(maxInteractionCount: 2)
        let result = limitedComposer.composeMemoryContext(
            memories: [low, high, mid],
            emotionalModel: nil
        )

        expect(result.text.contains("高分互动"), "high score interaction should appear")
        expect(result.text.contains("中分互动"), "mid score interaction should appear")
        expect(!result.text.contains("低分互动"), "low score interaction should be cut off at maxInteractionCount=2")
    }

    func interactionsLimitedToMaxCount() {
        let interactions = (0..<15).map { i in
            makeMemory(category: .interaction, content: "互动\(i)", importance: 0.5, accessCount: 0, id: "int-\(i)")
        }
        let limitedComposer = MemoryPromptComposer(maxInteractionCount: 5)
        let result = limitedComposer.composeMemoryContext(
            memories: interactions,
            emotionalModel: nil
        )

        let usedInteractionIds = result.usedMemoryIds.filter { $0.hasPrefix("int-") }
        expect(usedInteractionIds.count == 5, "should limit interactions to maxInteractionCount")
    }

    // MARK: - Emotional Model Section

    func emotionalModelSectionFormatted() {
        let model = AIEmotionalModel(
            relationshipPhase: .familiar,
            interactionStyle: .casual,
            topicsOfInterest: []
        )
        let result = composer.composeMemoryContext(memories: [], emotionalModel: model)

        expect(result.text.contains("【关于我们的关系】"), "should contain relationship section header")
        expect(result.text.contains("熟悉"), "should contain relationship phase name")
        expect(result.text.contains("轻松随意"), "should contain interaction style name")
    }

    func emotionalModelSectionTopics() {
        let model = AIEmotionalModel(
            topicsOfInterest: ["编程", "音乐", "猫"]
        )
        let result = composer.composeMemoryContext(memories: [], emotionalModel: model)

        expect(result.text.contains("编程"), "should contain first topic")
        expect(result.text.contains("音乐"), "should contain second topic")
        expect(result.text.contains("猫"), "should contain third topic")
    }

    func emotionalModelNilProducesNoRelationshipSection() {
        let result = composer.composeMemoryContext(memories: [], emotionalModel: nil)
        expect(!result.text.contains("关于我们的关系"), "should not contain relationship section when model is nil")
    }

    // MARK: - Important Memories

    func milestoneAndCustomInImportantMemories() {
        let milestone = makeMemory(category: .milestone, content: "用户毕业了")
        let custom = makeMemory(category: .custom, content: "我的猫叫小橘")

        let result = composer.composeMemoryContext(
            memories: [milestone, custom],
            emotionalModel: nil
        )

        expect(result.text.contains("【重要回忆】"), "should contain important memories section")
        expect(result.text.contains("毕业"), "milestone should be in important memories")
        expect(result.text.contains("小橘"), "custom should be in important memories")
    }

    // MARK: - usedMemoryIds

    func usedMemoryIdsCorrect() {
        let m1 = makeMemory(category: .nickname, content: "小明", id: "id-1")
        let m2 = makeMemory(category: .milestone, content: "毕业", id: "id-2")
        let m3 = makeMemory(category: .preference, content: "冷色", id: "id-3")
        let m4 = makeMemory(category: .interaction, content: "聊天", id: "id-4")

        let result = composer.composeMemoryContext(
            memories: [m1, m2, m3, m4],
            emotionalModel: nil
        )

        expect(result.usedMemoryIds.contains("id-1"), "should include nickname ID")
        expect(result.usedMemoryIds.contains("id-2"), "should include milestone ID")
        expect(result.usedMemoryIds.contains("id-3"), "should include preference ID")
        expect(result.usedMemoryIds.contains("id-4"), "should include interaction ID")
    }

    // MARK: - Token Estimate

    func tokenEstimatePositive() {
        let memories = [makeMemory(category: .preference, content: "喜欢冷色调")]
        let result = composer.composeMemoryContext(memories: memories, emotionalModel: nil)
        expect(result.tokenEstimate > 0, "token estimate should be positive")
    }

    // MARK: - Edge Cases

    func emptyMemoriesProduceEmptyResult() {
        let result = composer.composeMemoryContext(memories: [], emotionalModel: nil)
        expect(result.text.isEmpty, "should produce empty text with no memories or model")
        expect(result.usedMemoryIds.isEmpty, "should have no used IDs")
    }

    func onlyNicknameProducesAboutUserOnly() {
        let nickname = makeMemory(category: .nickname, content: "小明")
        let result = composer.composeMemoryContext(memories: [nickname], emotionalModel: nil)

        expect(result.text.contains("【关于用户】"), "should contain about user section")
        expect(!result.text.contains("【重要回忆】"), "should not contain important memories when only nickname")
        expect(result.text.contains("小明"), "should contain nickname content")
    }

    func multipleMemoriesAggregated() {
        let p1 = makeMemory(category: .preference, content: "冷色调")
        let p2 = makeMemory(category: .preference, content: "简洁回复")
        let result = composer.composeMemoryContext(memories: [p1, p2], emotionalModel: nil)

        expect(result.text.contains("冷色调"), "should contain first preference")
        expect(result.text.contains("简洁回复"), "should contain second preference")
    }

    func resultIsSendable() {
        let result = MemoryPromptResult(text: "test", usedMemoryIds: [], tokenEstimate: 1)
        expect(result.text == "test", "MemoryPromptResult should be initializable")
        expect(result.usedMemoryIds.isEmpty, "usedMemoryIds should be empty")
        expect(result.tokenEstimate == 1, "tokenEstimate should be 1")
    }

    func accessCountUsedInInteractionScore() {
        let lowAccess = makeMemory(category: .interaction, content: "低引用", importance: 0.9, accessCount: 0, id: "low-access")
        let highAccess = makeMemory(category: .interaction, content: "高引用", importance: 0.9, accessCount: 10, id: "high-access")

        let limitedComposer = MemoryPromptComposer(maxInteractionCount: 1)
        let result = limitedComposer.composeMemoryContext(
            memories: [lowAccess, highAccess],
            emotionalModel: nil
        )

        expect(result.text.contains("高引用"), "high access count memory should be preferred")
        expect(!result.text.contains("低引用"), "low access count memory should be excluded when limited")
    }
}
