import Foundation
import DesktopPet

@MainActor
func runBubblePhraseProviderTests() {
    let tests = BubblePhraseProviderTests()
    tests.returnsNilWhenTriggerHasNoPhrases()
    tests.returnsSelectorChoiceWhenPhrasesPresent()
    tests.defaultSelectorReturnsValuePresentInProfile()
    tests.respectsCustomSelectorPerCall()
}

@MainActor
private struct BubblePhraseProviderTests {
    func returnsNilWhenTriggerHasNoPhrases() {
        let profile = BubbleProfile(
            phrases: [.clicked: ["hi"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let provider = DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })

        let phrase = provider.phrase(for: .feed, state: .defaultState())
        expect(phrase == nil, "phrase should be nil when no candidates exist for trigger")
    }

    func returnsSelectorChoiceWhenPhrasesPresent() {
        let profile = BubbleProfile(
            phrases: [.pet: ["A", "B", "C"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let provider = DefaultBubblePhraseProvider(profile: profile, selector: { $0.last })

        expect(provider.phrase(for: .pet, state: .defaultState()) == "C", "selector should pick last when configured")
    }

    func defaultSelectorReturnsValuePresentInProfile() {
        let profile = BubbleProfile(
            phrases: [.feed: ["only"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let provider = DefaultBubblePhraseProvider(profile: profile)

        let phrase = provider.phrase(for: .feed, state: .defaultState())
        expect(phrase == "only", "default selector should return the only phrase available")
    }

    func respectsCustomSelectorPerCall() {
        var seen: [String] = []
        let selector: @Sendable ([String]) -> String? = { phrases in
            phrases.first
        }
        let profile = BubbleProfile(
            phrases: [.idle: ["x", "y"], .pet: ["alpha", "beta"]],
            minimumIntervalSeconds: 60,
            displayDurationSeconds: 3
        )
        let provider = DefaultBubblePhraseProvider(profile: profile, selector: selector)

        if let p1 = provider.phrase(for: .idle, state: .defaultState()) {
            seen.append(p1)
        }
        if let p2 = provider.phrase(for: .pet, state: .defaultState()) {
            seen.append(p2)
        }

        expect(seen == ["x", "alpha"], "selector should resolve per-trigger candidate list")
    }
}
