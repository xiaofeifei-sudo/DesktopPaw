import Foundation

public protocol BubblePhraseProviding: Sendable {
    func phrase(for trigger: BubbleTrigger, state: PetRuntimeState) -> String?
}

public struct DefaultBubblePhraseProvider: BubblePhraseProviding {
    public typealias PhraseSelector = @Sendable ([String]) -> String?

    private let profile: BubbleProfile
    private let selector: PhraseSelector

    public init(
        profile: BubbleProfile,
        selector: @escaping PhraseSelector = { $0.randomElement() }
    ) {
        self.profile = profile
        self.selector = selector
    }

    public func phrase(for trigger: BubbleTrigger, state: PetRuntimeState) -> String? {
        let candidates = profile.phrases(for: trigger)
        guard !candidates.isEmpty else {
            return nil
        }
        return selector(candidates)
    }
}
