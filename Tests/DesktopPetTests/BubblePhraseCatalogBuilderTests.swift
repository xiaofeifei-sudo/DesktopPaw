import Foundation
import DesktopPet

func runBubblePhraseCatalogBuilderTests() {
    let tests = BubblePhraseCatalogBuilderTests()
    tests.defaultCatalogCoversOriginalTriggers()
    tests.defaultCatalogCoversCompanionTriggers()
    tests.defaultCatalogHasRelationshipExclusivePhrases()
    tests.legacyProfileConvertsToPhrases()
    tests.legacyConvertPreservesTexts()
    tests.buildMergesLegacyWithDefaults()
    tests.buildWithoutProfileReturnsDefaults()
    tests.phraseDecodeEncodeRoundTrips()
    tests.phraseMatchesTrigger()
    tests.phraseMatchesRelationshipLevel()
    tests.phraseMatchesTimeSlots()
    tests.phraseMatchesMood()
    tests.phraseRejectsUnmatchedLevel()
    tests.catalogFilterByTriggerAndLevel()
    tests.catalogMergingDeduplicatesById()
}

private struct BubblePhraseCatalogBuilderTests {
    func defaultCatalogCoversOriginalTriggers() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        for trigger in [BubbleTrigger.clicked, .pet, .feed, .hungry, .tired, .happy, .idle, .walking, .sleeping] {
            let phrases = catalog.phrases(for: trigger)
            expect(!phrases.isEmpty, "default catalog must provide phrases for \(trigger.rawValue)")
        }
    }

    func defaultCatalogCoversCompanionTriggers() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        for trigger in [BubbleTrigger.dailyGreeting, .longAbsenceReturn, .relationshipLevelUp, .actionLine, .microDialogPrompt, .quietModeNotice] {
            let phrases = catalog.phrases(for: trigger)
            expect(!phrases.isEmpty, "default catalog must provide phrases for companion trigger \(trigger.rawValue)")
        }
    }

    func defaultCatalogHasRelationshipExclusivePhrases() {
        let catalog = BubblePhraseCatalogBuilder.defaultCatalog()
        let lv1Phrases = catalog.phrases(for: .idle, relationshipLevel: .acquaintance)
        let lv5Phrases = catalog.phrases(for: .idle, relationshipLevel: .bonded)
        expect(lv5Phrases.count > lv1Phrases.count, "Lv.5 should have more idle phrases than Lv.1 due to relationship-exclusive entries")
    }

    func legacyProfileConvertsToPhrases() {
        let profile = BubbleProfile(
            phrases: [.clicked: ["你好", "嗨"], .pet: ["开心"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let builder = BubblePhraseCatalogBuilder()
        let catalog = builder.convertLegacyProfile(profile)
        expect(catalog.phrases.count == 3, "legacy conversion should create one phrase per text")
        expect(catalog.phrases(for: .clicked).count == 2, "should have 2 clicked phrases")
        expect(catalog.phrases(for: .pet).count == 1, "should have 1 pet phrase")
    }

    func legacyConvertPreservesTexts() {
        let profile = BubbleProfile(
            phrases: [.feed: ["好吃", "满足了"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let builder = BubblePhraseCatalogBuilder()
        let catalog = builder.convertLegacyProfile(profile)
        let texts = catalog.phrases(for: .feed).map(\.text).sorted()
        expect(texts == ["好吃", "满足了"], "legacy conversion should preserve original texts")
    }

    func buildMergesLegacyWithDefaults() {
        let profile = BubbleProfile(
            phrases: [.clicked: ["custom_click"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let builder = BubblePhraseCatalogBuilder()
        let catalog = builder.build(from: profile)
        let clickedPhrases = catalog.phrases(for: .clicked)
        let hasCustom = clickedPhrases.contains { $0.text == "custom_click" }
        let hasDefault = clickedPhrases.contains { $0.id == "default_clicked_0" }
        expect(hasCustom, "merged catalog should include legacy phrase")
        expect(hasDefault, "merged catalog should include default phrase")
    }

    func buildWithoutProfileReturnsDefaults() {
        let builder = BubblePhraseCatalogBuilder()
        let catalog = builder.build(from: nil)
        expect(!catalog.isEmpty, "building without profile should return default catalog")
        expect(catalog.phrases(for: .clicked).count >= 3, "default should have multiple clicked phrases")
    }

    func phraseDecodeEncodeRoundTrips() {
        let phrase = BubblePhrase(
            id: "test_001",
            text: "你好",
            triggers: [.clicked, .pet],
            minRelationshipLevel: .familiar,
            maxRelationshipLevel: .trusted,
            moodTags: [.happy],
            timeTags: [.morning],
            priority: .interaction,
            weight: 1.5,
            cooldownSeconds: 30,
            canStartMicroDialog: true
        )
        do {
            let data = try JSONEncoder().encode(phrase)
            let decoded = try JSONDecoder().decode(BubblePhrase.self, from: data)
            expect(decoded == phrase, "BubblePhrase encode/decode round-trip should preserve data")
        } catch {
            fail("BubblePhrase round-trip failed: \(error)")
        }
    }

    func phraseMatchesTrigger() {
        let phrase = BubblePhrase(id: "t", text: "hi", triggers: [.clicked, .pet])
        expect(phrase.matchesTrigger(.clicked), "phrase should match its declared trigger")
        expect(phrase.matchesTrigger(.pet), "phrase should match multiple triggers")
        expect(!phrase.matchesTrigger(.feed), "phrase should not match undeclared trigger")
    }

    func phraseMatchesRelationshipLevel() {
        let phrase = BubblePhrase(id: "t", text: "hi", triggers: [.idle], minRelationshipLevel: .familiar, maxRelationshipLevel: .trusted)
        expect(!phrase.matchesRelationshipLevel(.acquaintance), "Lv.1 should not match min=familiar")
        expect(phrase.matchesRelationshipLevel(.familiar), "Lv.2 should match min=familiar")
        expect(phrase.matchesRelationshipLevel(.close), "Lv.3 should match within range")
        expect(phrase.matchesRelationshipLevel(.trusted), "Lv.4 should match max=trusted")
        expect(!phrase.matchesRelationshipLevel(.bonded), "Lv.5 should not match max=trusted")
    }

    func phraseMatchesTimeSlots() {
        let phrase = BubblePhrase(id: "t", text: "hi", triggers: [.idle], timeTags: [.morning])
        expect(phrase.matchesTimeSlots([.morning]), "should match morning slot")
        expect(phrase.matchesTimeSlots([.morning, .workday]), "should match when morning is included")
        expect(!phrase.matchesTimeSlots([.evening]), "should not match evening only")
        let noConstraint = BubblePhrase(id: "t2", text: "hi", triggers: [.idle])
        expect(noConstraint.matchesTimeSlots([.evening]), "empty timeTags should match any slot")
    }

    func phraseMatchesMood() {
        let phrase = BubblePhrase(id: "t", text: "hi", triggers: [.idle], moodTags: [.happy])
        expect(phrase.matchesMood([.happy]), "should match happy mood")
        expect(phrase.matchesMood([.happy, .calm]), "should match when happy is included")
        expect(!phrase.matchesMood([.sad]), "should not match sad mood")
        let noConstraint = BubblePhrase(id: "t2", text: "hi", triggers: [.idle])
        expect(noConstraint.matchesMood([.sad]), "empty moodTags should match any mood")
    }

    func phraseRejectsUnmatchedLevel() {
        let phrase = BubblePhrase(id: "t", text: "hi", triggers: [.idle], minRelationshipLevel: .close)
        expect(!phrase.matchesRelationshipLevel(.acquaintance), "Lv.1 should be rejected when min is Lv.3")
        expect(!phrase.matchesRelationshipLevel(.familiar), "Lv.2 should be rejected when min is Lv.3")
        expect(phrase.matchesRelationshipLevel(.close), "Lv.3 should be accepted when min is Lv.3")
        expect(phrase.matchesRelationshipLevel(.bonded), "Lv.5 should be accepted when min is Lv.3")
    }

    func catalogFilterByTriggerAndLevel() {
        let catalog = BubblePhraseCatalog(phrases: [
            BubblePhrase(id: "a", text: "a", triggers: [.idle]),
            BubblePhrase(id: "b", text: "b", triggers: [.idle], minRelationshipLevel: .close),
            BubblePhrase(id: "c", text: "c", triggers: [.clicked]),
        ])
        let lv1Idle = catalog.phrases(for: .idle, relationshipLevel: .acquaintance)
        expect(lv1Idle.count == 1, "Lv.1 should only see unconstrained idle phrase")
        let lv5Idle = catalog.phrases(for: .idle, relationshipLevel: .bonded)
        expect(lv5Idle.count == 2, "Lv.5 should see both unconstrained and close+ idle phrases")
        let clicked = catalog.phrases(for: .clicked, relationshipLevel: .acquaintance)
        expect(clicked.count == 1, "clicked filter should work")
    }

    func catalogMergingDeduplicatesById() {
        let a = BubblePhraseCatalog(phrases: [
            BubblePhrase(id: "x", text: "first", triggers: [.idle]),
            BubblePhrase(id: "y", text: "y", triggers: [.idle]),
        ])
        let b = BubblePhraseCatalog(phrases: [
            BubblePhrase(id: "x", text: "duplicate", triggers: [.idle]),
            BubblePhrase(id: "z", text: "z", triggers: [.idle]),
        ])
        let merged = a.merging(with: b)
        expect(merged.phrases.count == 3, "merging should deduplicate by id")
        let xPhrase = merged.phrase(withId: "x")
        expect(xPhrase?.text == "first", "first catalog should take precedence for duplicate ids")
    }
}
