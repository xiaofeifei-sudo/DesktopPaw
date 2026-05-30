import Foundation
import DesktopPet

@MainActor
func runContextualBubblePhraseProviderTests() {
    let tests = ContextualBubblePhraseProviderTests()
    tests.basicTriggerFilteringReturnsNilForUnmatched()
    tests.relationshipLevelFilteringExcludesHighLevelPhrases()
    tests.quietModeSuppressesIdleAndAmbientPhrases()
    tests.relationshipPromptsToggleSuppressesLevelUpAndReturn()
    tests.recentTextDeduplicationReducesWeight()
    tests.templateRenderingReplacesPetAndUser()
    tests.emptyNicknameFallback()
    tests.returnsNilWhenNoCandidates()
    tests.phraseCooldownPreventsRapidReuse()
}

@MainActor
private struct ContextualBubblePhraseProviderTests {

    // MARK: - Test 1: Basic trigger filtering

    func basicTriggerFilteringReturnsNilForUnmatched() {
        let phrase = BubblePhrase(
            id: "click_0", text: "你好",
            triggers: [.clicked], priority: .interaction
        )
        let catalog = BubblePhraseCatalog(phrases: [phrase])
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext()
        let result = provider.phrase(for: .feed, context: ctx)

        expect(result == nil, "should return nil when trigger does not match any phrase")
    }

    // MARK: - Test 2: Relationship level filtering

    func relationshipLevelFilteringExcludesHighLevelPhrases() {
        let phrases = [
            BubblePhrase(id: "basic_idle", text: "陪你", triggers: [.idle], priority: .ambient),
            BubblePhrase(id: "close_idle", text: "陪着你", triggers: [.idle], minRelationshipLevel: .close, priority: .ambient),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext(relationshipLevel: .acquaintance)
        let result = provider.phrase(for: .idle, context: ctx)

        expect(result != nil, "should return a phrase when some candidates match the level")
        expect(result?.phrase.id == "basic_idle", "should exclude Lv.3 phrase for Lv.1 relationship")
    }

    // MARK: - Test 3: Quiet mode suppresses idle/ambient phrases

    func quietModeSuppressesIdleAndAmbientPhrases() {
        let phrases = [
            BubblePhrase(id: "idle_0", text: "陪你", triggers: [.idle], priority: .ambient),
            BubblePhrase(id: "walk_0", text: "溜达", triggers: [.walking], priority: .ambient),
            BubblePhrase(id: "greet_0", text: "你好", triggers: [.dailyGreeting], priority: .relationship),
            BubblePhrase(id: "click_0", text: "嘿", triggers: [.clicked], priority: .interaction),
            BubblePhrase(id: "quiet_0", text: "安静模式", triggers: [.quietModeNotice], priority: .state),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let now = Date()
        let futureDate = now.addingTimeInterval(600)
        let ctx = makeContext(quietUntil: futureDate)

        let idle = provider.phrase(for: .idle, context: ctx, now: now)
        expect(idle == nil, "quiet mode should suppress .idle trigger")

        let walking = provider.phrase(for: .walking, context: ctx, now: now)
        expect(walking == nil, "quiet mode should suppress .walking trigger")

        let greeting = provider.phrase(for: .dailyGreeting, context: ctx, now: now)
        expect(greeting == nil, "quiet mode should suppress .dailyGreeting trigger")

        let clicked = provider.phrase(for: .clicked, context: ctx, now: now)
        expect(clicked != nil, "quiet mode should NOT suppress .clicked trigger")
    }

    // MARK: - Test 4: Relationship prompts toggle

    func relationshipPromptsToggleSuppressesLevelUpAndReturn() {
        let phrases = [
            BubblePhrase(id: "levelup_0", text: "更亲近了", triggers: [.relationshipLevelUp], priority: .relationship),
            BubblePhrase(id: "return_0", text: "欢迎回来", triggers: [.longAbsenceReturn], priority: .relationship),
            BubblePhrase(id: "idle_0", text: "陪你", triggers: [.idle], priority: .ambient),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext(showRelationshipPrompts: false)

        let levelUp = provider.phrase(for: .relationshipLevelUp, context: ctx)
        expect(levelUp == nil, "should suppress .relationshipLevelUp when showRelationshipPrompts is false")

        let ret = provider.phrase(for: .longAbsenceReturn, context: ctx)
        expect(ret == nil, "should suppress .longAbsenceReturn when showRelationshipPrompts is false")

        let idle = provider.phrase(for: .idle, context: ctx)
        expect(idle != nil, "should NOT suppress .idle when showRelationshipPrompts is false")
    }

    // MARK: - Test 5: Recent text deduplication

    func recentTextDeduplicationReducesWeight() {
        let phrases = [
            BubblePhrase(id: "a", text: "你好", triggers: [.clicked], weight: 1.0),
            BubblePhrase(id: "b", text: "嗨", triggers: [.clicked], weight: 1.0),
            BubblePhrase(id: "c", text: "在呢", triggers: [.clicked], weight: 1.0),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)

        // Phase 1: roll=0.0 picks the first candidate
        let provider1 = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { _ in 0.0 }
        )
        let ctx1 = makeContext(recentBubbleTexts: [])
        let r1 = provider1.phrase(for: .clicked, context: ctx1)
        expect(r1 != nil, "should select a phrase when no recent texts")
        expect(r1?.phrase.id == "a", "roll=0.0 should pick the first candidate")

        // Phase 2: "你好" is in recent texts; roll=0.0 still picks it
        // (weight adjusted to 0.7, roll 0.0 <= cumulative 0.7)
        let ctx2 = makeContext(recentBubbleTexts: ["你好"])
        let r2 = provider1.phrase(for: .clicked, context: ctx2)
        expect(r2?.phrase.id == "a", "roll=0.0 should still pick the first candidate even if deduped")
        expect(r2?.renderedText == "你好", "rendered text should be the phrase text when no placeholders")

        // Phase 3: verify deduped phrase is not excluded — still pickable with low roll
        var pickCounts: [String: Int] = [:]
        let lowRollProvider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )
        for _ in 0..<10 {
            let ctx = makeContext(recentBubbleTexts: ["你好"])
            if let sel = lowRollProvider.phrase(for: .clicked, context: ctx) {
                pickCounts[sel.phrase.id, default: 0] += 1
            }
        }
        expect(pickCounts["a"] != nil, "deduped phrase should still be pickable with low roll")
    }

    // MARK: - Test 6: Template rendering

    func templateRenderingReplacesPetAndUser() {
        let phrases = [
            BubblePhrase(id: "tpl", text: "{pet}喜欢{user}", triggers: [.clicked], weight: 1.0),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext(petDisplayName: "Starter Pet", petNickname: "Mochi", userNickname: "Alex")
        let result = provider.phrase(for: .clicked, context: ctx)

        expect(result?.renderedText == "Mochi喜欢Alex", "should replace {pet} and {user} placeholders")
        expect(result?.phrase.text == "{pet}喜欢{user}", "original phrase.text should be unchanged")
    }

    // MARK: - Test 7: Empty nickname fallback

    func emptyNicknameFallback() {
        let phrases = [
            BubblePhrase(id: "tpl", text: "{pet}向{user}问好", triggers: [.clicked]),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext(petDisplayName: "Pet", petNickname: nil, userNickname: nil)
        let result = provider.phrase(for: .clicked, context: ctx)

        expect(result != nil, "should return a result for .clicked trigger with template phrase")
        let rendered = result?.renderedText ?? ""
        expect(rendered.contains("Pet"), "should use petDisplayName when petNickname is nil")
        expect(!rendered.contains("{pet}"), "rendered text should not contain {pet} placeholder")
        expect(!rendered.contains("{user}"), "rendered text should not contain {user} placeholder")
    }

    // MARK: - Test 8: Returns nil when no candidates

    func returnsNilWhenNoCandidates() {
        let catalog = BubblePhraseCatalog(phrases: [])
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = makeContext()
        let result = provider.phrase(for: .clicked, context: ctx)

        expect(result == nil, "should return nil when catalog has no phrases for the trigger")
    }

    // MARK: - Test 9: Phrase cooldown prevents rapid reuse

    func phraseCooldownPreventsRapidReuse() {
        let now = Date()
        let phrases = [
            BubblePhrase(
                id: "cool_0", text: "嗨", triggers: [.clicked],
                weight: 1.0, cooldownSeconds: 5.0
            ),
        ]
        let catalog = BubblePhraseCatalog(phrases: phrases)
        let tracker = InMemoryPhraseCooldownTracker(catalog: catalog)

        // Phase 1: first call succeeds
        let provider1 = ContextualBubblePhraseProvider(
            catalog: catalog,
            phraseCooldownTracker: tracker,
            randomProvider: { range in range.lowerBound }
        )
        let ctx1 = makeContext()
        let r1 = provider1.phrase(for: .clicked, context: ctx1, now: now)
        expect(r1 != nil, "first call should succeed with no cooldown")
        expect(r1?.phrase.id == "cool_0", "first call should return the phrase")

        // Phase 2: immediate second call blocked by cooldown
        let ctx2 = makeContext()
        let r2 = provider1.phrase(for: .clicked, context: ctx2, now: now.addingTimeInterval(1.0))
        expect(r2 == nil, "second call within cooldown window should return nil")

        // Phase 3: after cooldown expires, call succeeds again
        let ctx3 = makeContext()
        let r3 = provider1.phrase(for: .clicked, context: ctx3, now: now.addingTimeInterval(6.0))
        expect(r3 != nil, "call after cooldown expiry should succeed")
        expect(r3?.phrase.id == "cool_0", "call after cooldown expiry should return the phrase")
    }

    // MARK: - Helpers

    private func makeContext(
        now: Date = Date(),
        petDisplayName: String = "Starter Pet",
        petNickname: String? = nil,
        userNickname: String? = nil,
        relationshipLevel: RelationshipLevel = .acquaintance,
        hunger: Double = 0.2,
        energy: Double = 0.8,
        mood: Double = 0.8,
        timeSlots: Set<CompanionTimeSlot> = [.morning, .workday],
        recentBubbleTexts: [String] = [],
        quietUntil: Date? = nil,
        showRelationshipPrompts: Bool = true
    ) -> CompanionContext {
        let runtimeState = PetRuntimeState(
            currentState: .idle,
            mood: mood,
            hunger: hunger,
            energy: energy,
            lastInteractionAt: now,
            isDragging: false,
            scale: 1.0
        )
        let relationship = RelationshipState(
            intimacyPoints: relationshipLevel.minimumPoints
        ).snapshot
        let preferences = CompanionPreferences(
            showRelationshipPrompts: showRelationshipPrompts,
            userNickname: userNickname,
            quietUntil: quietUntil
        )
        return CompanionContext(
            petId: "pet-a",
            petDisplayName: petDisplayName,
            petNickname: petNickname,
            userNickname: userNickname,
            runtimeState: runtimeState,
            relationship: relationship,
            preferences: preferences,
            timeSlots: timeSlots,
            recentBubbleTexts: recentBubbleTexts
        )
    }
}
