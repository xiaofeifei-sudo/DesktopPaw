import Foundation

@MainActor
public final class InteractiveBubblePresenter: InteractiveBubblePresenting, Sendable {
    private let settings: any InteractiveBubbleSettingsProviding

    public var onFeedbackCompleted: (() -> Void)?
    public var onTimeout: (() -> Void)?

    private var currentBubble: InteractiveBubble?
    private var timeoutExpiresAt: Date?
    private var feedbackText: String?
    private var feedbackExpiresAt: Date?

    public var isActive: Bool {
        currentBubble != nil || feedbackText != nil
    }

    #if DEBUG
    public var currentBubbleForTesting: InteractiveBubble? { currentBubble }
    public var feedbackTextForTesting: String? { feedbackText }
    #endif

    public init(settings: any InteractiveBubbleSettingsProviding) {
        self.settings = settings
    }

    // MARK: - InteractiveBubblePresenting

    public func show(_ bubble: InteractiveBubble) {
        guard !isActive else { return }
        currentBubble = bubble
        timeoutExpiresAt = .now + settings.optionWaitDuration
    }

    public func dismiss() {
        currentBubble = nil
        timeoutExpiresAt = nil
    }

    public func dismissWithFeedback(_ text: String) {
        currentBubble = nil
        timeoutExpiresAt = nil
        feedbackText = text
        feedbackExpiresAt = .now + 3.0
    }

    // MARK: - Tick Integration

    public func checkTimeout(at date: Date) {
        if currentBubble != nil,
           let expiresAt = timeoutExpiresAt,
           date >= expiresAt {
            currentBubble = nil
            timeoutExpiresAt = nil
            onTimeout?()
        }

        if feedbackText != nil,
           let expiresAt = feedbackExpiresAt,
           date >= expiresAt {
            feedbackText = nil
            feedbackExpiresAt = nil
            onFeedbackCompleted?()
        }
    }
}
