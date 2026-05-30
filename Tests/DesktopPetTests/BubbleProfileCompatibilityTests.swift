import Foundation
import DesktopPet

@MainActor
func runBubbleProfileCompatibilityTests() {
    let tests = BubbleProfileCompatibilityTests()
    tests.oldBubbleTriggerDecodesAllOriginalCases()
    tests.newTriggerCasesDecodable()
    tests.legacyPhrasesHaveDefaultPriority()
    tests.defaultCatalogPhrasesHaveNonEmptyText()
    tests.defaultCatalogPhrasesHaveUniqueIds()
    tests.defaultPhrasesRespectContentLength()
    tests.newBubblePriorityOrdering()
    tests.defaultPhrasesPassSafetyTone()
    tests.oldBubbleProfileWorksWithBubbleEngine()
    tests.legacyAmbientTriggerStillEmitsBubble()
    tests.bubbleEngineLegacyEntryPointsStillWork()
}

@MainActor
private struct BubbleProfileCompatibilityTests {
    func oldBubbleTriggerDecodesAllOriginalCases() {
        let json = """
        {
          "minimumIntervalSeconds": 60,
          "displayDurationSeconds": 3,
          "phrases": {
            "clicked": ["hi"],
            "pet": ["happy"],
            "feed": ["yum"],
            "hungry": ["hungry"],
            "tired": ["tired"],
            "happy": ["happy"],
            "idle": ["idle"],
            "walking": ["walk"],
            "sleeping": ["zzz"]
          }
        }
        """
        do {
            let profile = try JSONDecoder().decode(BubbleProfile.self, from: Data(json.utf8))
            expect(profile.phrases.count == 9, "all 9 original triggers should decode")
            expect(profile.phrases[.clicked] == ["hi"], "clicked phrases should be preserved")
        } catch {
            fail("old profile JSON should decode: \(error)")
        }
    }

    func newTriggerCasesDecodable() {
        for trigger in BubbleTrigger.allCases {
            expect(!trigger.rawValue.isEmpty, "trigger \(trigger) should have non-empty raw value")
        }
        expect(BubbleTrigger.allCases.count >= 15, "should have all original + companion triggers")
    }

    func legacyPhrasesHaveDefaultPriority() {
        let profile = BubbleProfile(
            phrases: [.clicked: ["hi"], .hungry: ["hungry"], .idle: ["idle"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let builder = BubblePhraseCatalogBuilder()
        let catalog = builder.convertLegacyProfile(profile)

        let clicked = catalog.phrases(for: .clicked)
        expect(clicked.first?.priority == .interaction, "legacy clicked should have interaction priority")

        let hungry = catalog.phrases(for: .hungry)
        expect(hungry.first?.priority == .state, "legacy hungry should have state priority")

        let idle = catalog.phrases(for: .idle)
        expect(idle.first?.priority == .ambient, "legacy idle should have ambient priority")
    }

    func defaultCatalogPhrasesHaveNonEmptyText() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        for phrase in catalog.phrases {
            expect(!phrase.text.trimmingCharacters(in: .whitespaces).isEmpty,
                   "phrase \(phrase.id) should have non-empty text")
        }
    }

    func defaultCatalogPhrasesHaveUniqueIds() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        let ids = catalog.phrases.map(\.id)
        let uniqueIds = Set(ids)
        expect(ids.count == uniqueIds.count, "all default phrases should have unique ids")
    }

    func defaultPhrasesRespectContentLength() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        for phrase in catalog.phrases {
            let charCount = phrase.text.count
            expect(charCount <= 12, "phrase '\(phrase.text)' should be <= 12 characters (got \(charCount))")
        }
    }

    func newBubblePriorityOrdering() {
        expect(BubblePriority.decorative < .ambient, "decorative < ambient")
        expect(BubblePriority.ambient < .relationship, "ambient < relationship")
        expect(BubblePriority.relationship < .state, "relationship < state")
        expect(BubblePriority.state < .interaction, "state < interaction")
        expect(BubblePriority.decorative < .interaction, "decorative < interaction")
    }

    func defaultPhrasesPassSafetyTone() {
        let prohibited = [
            "你怎么才来", "你是不是忘了我", "你不来我会难过",
            "你只能陪我", "我能治好你的焦虑", "现在必须休息",
            "我只有你了", "升级才能让我更爱你",
        ]
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        for phrase in catalog.phrases {
            for banned in prohibited {
                expect(!phrase.text.contains(banned),
                       "phrase '\(phrase.text)' should not contain prohibited text '\(banned)'")
            }
        }
    }

    @MainActor
    func oldBubbleProfileWorksWithBubbleEngine() {
        let profile = BubbleProfileDefaults.defaultProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = PetRuntimeState.defaultState(at: now)

        let clicked = engine.handle(event: .clicked, state: state, at: now)
        expect(clicked != nil, "old profile should still produce click bubbles")
        expect(clicked?.text == "你好", "old profile click bubble should use legacy phrase text")
    }

    @MainActor
    func legacyAmbientTriggerStillEmitsBubble() {
        let profile = BubbleProfileDefaults.defaultProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = PetRuntimeState.defaultState(at: now)
        state.currentState = .idle
        state.hunger = 0.1
        state.energy = 0.9

        let bubble = engine.tick(state: state, at: now.addingTimeInterval(BubbleEngine.idleAmbientSeconds + 5))
        expect(bubble != nil, "legacy ambient trigger should still produce bubble")
        expect(bubble?.priority == .ambient, "ambient bubble should have ambient priority")
    }

    @MainActor
    func bubbleEngineLegacyEntryPointsStillWork() {
        let profile = BubbleProfileDefaults.defaultProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = PetRuntimeState.defaultState(at: now)

        let pet = engine.handle(event: .pet, state: state, at: now)
        expect(pet?.priority == .interaction, "pet event should produce interaction bubble")

        let feed = engine.handle(event: .feed, state: state, at: now.addingTimeInterval(1))
        expect(feed?.priority == .interaction, "feed event should produce interaction bubble")
    }
}
