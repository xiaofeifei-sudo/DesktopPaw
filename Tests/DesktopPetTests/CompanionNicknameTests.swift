import Foundation
import DesktopPet

@MainActor
func runCompanionNicknameTests() {
    let tests = CompanionNicknameTests()
    tests.petANicknameDoesNotAffectPetB()
    tests.petNicknameRendersInBubbleTemplate()
    tests.userNicknameRendersInBubbleTemplate()
    tests.clearingNicknameRestoresDefault()
    tests.switchingPetUpdatesCurrentPetNickname()
}

@MainActor
private struct CompanionNicknameTests {
    private func makeStore() -> CompanionPreferencesStore {
        let defaults = UserDefaults(suiteName: "CompanionNicknameTests-\(UUID().uuidString)")!
        return CompanionPreferencesStore(userDefaults: defaults)
    }

    func petANicknameDoesNotAffectPetB() {
        let store = makeStore()

        store.setPetNickname("Mochi", for: "pet-a")
        store.setPetNickname("Nori", for: "pet-b")

        let prefs = store.loadPreferences()
        expect(prefs.petNicknamesByPetId["pet-a"] == "Mochi", "pet-a nickname should be Mochi")
        expect(prefs.petNicknamesByPetId["pet-b"] == "Nori", "pet-b nickname should be Nori")

        store.setPetNickname(nil, for: "pet-a")
        let updated = store.loadPreferences()
        expect(updated.petNicknamesByPetId["pet-a"] == nil, "pet-a nickname should be cleared")
        expect(updated.petNicknamesByPetId["pet-b"] == "Nori", "pet-b nickname should remain Nori")
    }

    func petNicknameRendersInBubbleTemplate() {
        let phrase = BubblePhrase(
            id: "test_pet", text: "{pet}你好",
            triggers: [.clicked], priority: .interaction
        )
        let catalog = BubblePhraseCatalog(phrases: [phrase])
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        var ctx = makeContext()
        ctx = CompanionContext(
            petId: ctx.petId,
            petDisplayName: ctx.petDisplayName,
            petNickname: "Mochi",
            userNickname: ctx.userNickname,
            runtimeState: ctx.runtimeState,
            relationship: ctx.relationship,
            preferences: ctx.preferences,
            timeSlots: ctx.timeSlots,
            recentBubbleTexts: ctx.recentBubbleTexts,
            lastCompanionEvent: ctx.lastCompanionEvent
        )

        let result = provider.phrase(for: .clicked, context: ctx)
        expect(result != nil, "should find a phrase")
        expect(result!.renderedText == "Mochi你好", "{pet} should be replaced with pet nickname")
    }

    func userNicknameRendersInBubbleTemplate() {
        let phrase = BubblePhrase(
            id: "test_user", text: "嗨{user}",
            triggers: [.dailyGreeting], priority: .ambient
        )
        let catalog = BubblePhraseCatalog(phrases: [phrase])
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        var ctx = makeContext()
        ctx = CompanionContext(
            petId: ctx.petId,
            petDisplayName: ctx.petDisplayName,
            petNickname: ctx.petNickname,
            userNickname: "Alex",
            runtimeState: ctx.runtimeState,
            relationship: ctx.relationship,
            preferences: ctx.preferences,
            timeSlots: ctx.timeSlots,
            recentBubbleTexts: ctx.recentBubbleTexts,
            lastCompanionEvent: ctx.lastCompanionEvent
        )

        let result = provider.phrase(for: .dailyGreeting, context: ctx)
        expect(result != nil, "should find a phrase")
        expect(result!.renderedText == "嗨Alex", "{user} should be replaced with user nickname")
    }

    func clearingNicknameRestoresDefault() {
        let store = makeStore()
        store.setPetNickname("  ", for: "pet-a")
        store.setUserNickname("  ")

        let prefs = store.loadPreferences()
        expect(prefs.petNicknamesByPetId["pet-a"] == nil, "whitespace-only pet nickname should be cleared")
        expect(prefs.userNickname == nil, "whitespace-only user nickname should be cleared")

        let phrase = BubblePhrase(
            id: "test_fallback", text: "{pet}找{user}",
            triggers: [.idle], priority: .ambient
        )
        let catalog = BubblePhraseCatalog(phrases: [phrase])
        let provider = ContextualBubblePhraseProvider(
            catalog: catalog,
            randomProvider: { range in range.lowerBound }
        )

        let ctx = CompanionContext(
            petId: "pet-a",
            petDisplayName: "DefaultPet",
            petNickname: nil,
            userNickname: nil,
            runtimeState: PetRuntimeState.defaultState(at: Date()),
            relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
            preferences: CompanionPreferences(),
            timeSlots: [.morning],
            recentBubbleTexts: [],
            lastCompanionEvent: nil
        )

        let result = provider.phrase(for: .idle, context: ctx)
        expect(result != nil, "should find a phrase")
        expect(result!.renderedText == "DefaultPet找", "nil pet nickname should use displayName, nil user nickname should be empty")
    }

    func switchingPetUpdatesCurrentPetNickname() {
        var prefs = CompanionPreferences()
        prefs.petNicknamesByPetId = ["pet-a": "Mochi", "pet-b": "Nori"]

        let model = CompanionshipSettingsViewModel(
            currentPetId: "pet-a",
            preferences: prefs
        )
        expect(model.currentPetNickname == "Mochi", "current pet nickname should be Mochi")

        model.updatePetId("pet-b")
        expect(model.currentPetNickname == "Nori", "after switch, pet nickname should be Nori")

        model.updatePetId("pet-c")
        expect(model.currentPetNickname == nil, "unknown pet should have no nickname")
    }
}

private func makeContext(
    petId: String = "test-pet",
    petDisplayName: String = "TestPet"
) -> CompanionContext {
    CompanionContext(
        petId: petId,
        petDisplayName: petDisplayName,
        petNickname: nil,
        userNickname: nil,
        runtimeState: PetRuntimeState.defaultState(at: Date()),
        relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: CompanionPreferences(),
        timeSlots: [.morning],
        recentBubbleTexts: [],
        lastCompanionEvent: nil
    )
}
