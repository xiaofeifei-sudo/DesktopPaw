import Foundation

@MainActor
public final class BubbleCommander: BubbleCommanding {
    private let bubbleEngine: BubbleEngine
    private var lastBubble: PetBubble?

    public var onBubbleChanged: ((PetBubble?) -> Void)?

    public init(bubbleEngine: BubbleEngine) {
        self.bubbleEngine = bubbleEngine
        self.lastBubble = bubbleEngine.currentBubble
    }

    public var currentBubble: PetBubble? { bubbleEngine.currentBubble }

    public func setSpeechBubbleEnabled(_ enabled: Bool) {
        bubbleEngine.isEnabled = enabled
        publishCurrent()
    }

    public func setBubbleFrequency(_ frequency: BubbleFrequency) {
        bubbleEngine.frequency = frequency
    }

    public func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date) {
        _ = bubbleEngine.handle(event: event, state: state, at: date)
        publishCurrent()
    }

    public func handleTick(state: PetRuntimeState, at date: Date) {
        _ = bubbleEngine.tick(state: state, at: date)
        publishCurrent()
    }

    public func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date) {
        _ = bubbleEngine.handle(trigger: trigger, context: context, at: date)
        publishCurrent()
    }

    public func handleCompanionTick(context: CompanionContext, at date: Date) {
        _ = bubbleEngine.tick(context: context, at: date)
        publishCurrent()
    }

    private func publishCurrent() {
        let current = bubbleEngine.currentBubble
        guard current != lastBubble else {
            return
        }

        lastBubble = current
        onBubbleChanged?(current)
    }
}
