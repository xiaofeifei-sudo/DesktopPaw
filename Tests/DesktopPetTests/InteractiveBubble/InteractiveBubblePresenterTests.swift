import Foundation
import DesktopPet

@MainActor
func runInteractiveBubblePresenterTests() {
    let tests = InteractiveBubblePresenterTests()
    tests.showSetsBubbleAndIsActive()
    tests.showWhenActiveIsIgnored()
    tests.dismissClearsBubbleAndIsActive()
    tests.dismissWithFeedbackClearsBubbleAndShowsFeedback()
    tests.showDuringFeedbackIsIgnored()
    tests.timeoutFiresAtExpiry()
    tests.timeoutDoesNotFireBeforeExpiry()
    tests.timeoutCallsOnTimeout()
    tests.timeoutDismissesWithoutFeedback()
    tests.feedbackAutoDismissesAfter3Seconds()
    tests.feedbackCallsOnFeedbackCompleted()
    tests.feedbackDoesNotDismissBefore3Seconds()
    tests.dismissCancelsTimeout()
    tests.dismissWithFeedbackCancelsTimeout()
    tests.multipleTimeoutsTrackCorrectly()
}

@MainActor
private struct InteractiveBubblePresenterTests {
    private func makePresenter(optionWaitDuration: TimeInterval = 15) -> InteractiveBubblePresenter {
        let settings = MockSettings(optionWaitDuration: optionWaitDuration)
        return InteractiveBubblePresenter(settings: settings)
    }

    private func makeBubble(text: String = "test bubble") -> InteractiveBubble {
        InteractiveBubble(
            text: text,
            type: .needExpression,
            options: [
                BubbleOption(emoji: "🍪", label: "给你弄好吃的", effect: .feed, isPrimary: true),
                BubbleOption(emoji: "⏳", label: "等一下哦", effect: .none, isPrimary: false)
            ],
            expiresAt: Date() + 60
        )
    }

    func showSetsBubbleAndIsActive() {
        let presenter = makePresenter()
        let bubble = makeBubble()

        presenter.show(bubble)

        expect(presenter.isActive, "show should make isActive true")
        expect(presenter.currentBubbleForTesting == bubble, "show should set currentBubble")
    }

    func showWhenActiveIsIgnored() {
        let presenter = makePresenter()
        let first = makeBubble(text: "first")
        let second = makeBubble(text: "second")

        presenter.show(first)
        presenter.show(second)

        expect(presenter.currentBubbleForTesting?.text == "first",
               "show when active should ignore new bubble")
    }

    func dismissClearsBubbleAndIsActive() {
        let presenter = makePresenter()
        presenter.show(makeBubble())

        presenter.dismiss()

        expect(!presenter.isActive, "dismiss should make isActive false")
        expect(presenter.currentBubbleForTesting == nil, "dismiss should clear currentBubble")
    }

    func dismissWithFeedbackClearsBubbleAndShowsFeedback() {
        let presenter = makePresenter()
        presenter.show(makeBubble())

        presenter.dismissWithFeedback("好吃好吃！满足~")

        expect(presenter.currentBubbleForTesting == nil,
               "dismissWithFeedback should clear currentBubble")
        expect(presenter.feedbackTextForTesting == "好吃好吃！满足~",
               "dismissWithFeedback should set feedbackText")
        expect(presenter.isActive, "isActive should be true while feedback is showing")
    }

    func showDuringFeedbackIsIgnored() {
        let presenter = makePresenter()
        presenter.show(makeBubble())
        presenter.dismissWithFeedback("好吃~")

        presenter.show(makeBubble(text: "new bubble"))

        expect(presenter.currentBubbleForTesting == nil,
               "show during feedback should be ignored")
        expect(presenter.feedbackTextForTesting == "好吃~",
               "feedback text should remain unchanged")
    }

    func timeoutFiresAtExpiry() {
        let presenter = makePresenter(optionWaitDuration: 15)
        presenter.show(makeBubble())

        let atExpiry = Date.now.addingTimeInterval(16)
        presenter.checkTimeout(at: atExpiry)

        expect(presenter.currentBubbleForTesting == nil,
               "timeout at expiry should clear currentBubble")
    }

    func timeoutDoesNotFireBeforeExpiry() {
        let presenter = makePresenter(optionWaitDuration: 15)
        presenter.show(makeBubble())

        let beforeExpiry = Date.now.addingTimeInterval(14)
        presenter.checkTimeout(at: beforeExpiry)

        expect(presenter.currentBubbleForTesting != nil,
               "timeout before expiry should not clear bubble")
    }

    func timeoutCallsOnTimeout() {
        let presenter = makePresenter(optionWaitDuration: 15)
        var timeoutCalled = false
        presenter.onTimeout = { timeoutCalled = true }

        presenter.show(makeBubble())
        presenter.checkTimeout(at: Date.now.addingTimeInterval(16))

        expect(timeoutCalled, "onTimeout should be called when timeout fires")
    }

    func timeoutDismissesWithoutFeedback() {
        let presenter = makePresenter(optionWaitDuration: 15)
        presenter.show(makeBubble())

        presenter.checkTimeout(at: Date.now.addingTimeInterval(16))

        expect(presenter.feedbackTextForTesting == nil,
               "timeout should not set feedbackText")
        expect(!presenter.isActive, "timeout should make isActive false")
    }

    func feedbackAutoDismissesAfter3Seconds() {
        let presenter = makePresenter()
        presenter.show(makeBubble())
        presenter.dismissWithFeedback("好吃~")

        presenter.checkTimeout(at: Date.now.addingTimeInterval(4.0))

        expect(presenter.feedbackTextForTesting == nil,
               "feedback should be cleared after 3 seconds")
        expect(!presenter.isActive, "isActive should be false after feedback clears")
    }

    func feedbackCallsOnFeedbackCompleted() {
        let presenter = makePresenter()
        var completedCalled = false
        presenter.onFeedbackCompleted = { completedCalled = true }

        presenter.show(makeBubble())
        presenter.dismissWithFeedback("好吃~")
        presenter.checkTimeout(at: Date.now.addingTimeInterval(4.0))

        expect(completedCalled, "onFeedbackCompleted should be called after 3 seconds")
    }

    func feedbackDoesNotDismissBefore3Seconds() {
        let presenter = makePresenter()
        presenter.show(makeBubble())
        presenter.dismissWithFeedback("好吃~")

        presenter.checkTimeout(at: Date.now.addingTimeInterval(2.9))

        expect(presenter.feedbackTextForTesting == "好吃~",
               "feedback should not be cleared before 3 seconds")
        expect(presenter.isActive, "isActive should still be true before feedback clears")
    }

    func dismissCancelsTimeout() {
        let presenter = makePresenter(optionWaitDuration: 15)
        var timeoutCalled = false
        presenter.onTimeout = { timeoutCalled = true }

        presenter.show(makeBubble())
        presenter.dismiss()
        presenter.checkTimeout(at: Date.now.addingTimeInterval(16))

        expect(!timeoutCalled, "dismiss should cancel pending timeout")
    }

    func dismissWithFeedbackCancelsTimeout() {
        let presenter = makePresenter(optionWaitDuration: 15)
        var timeoutCalled = false
        presenter.onTimeout = { timeoutCalled = true }

        presenter.show(makeBubble())
        presenter.dismissWithFeedback("好吃~")
        presenter.checkTimeout(at: Date.now.addingTimeInterval(16))

        expect(!timeoutCalled, "dismissWithFeedback should cancel pending timeout")
    }

    func multipleTimeoutsTrackCorrectly() {
        let presenter = makePresenter(optionWaitDuration: 10)

        presenter.show(makeBubble(text: "first"))
        presenter.checkTimeout(at: Date.now.addingTimeInterval(11))
        expect(presenter.currentBubbleForTesting == nil, "first should timeout")

        presenter.show(makeBubble(text: "second"))
        expect(presenter.currentBubbleForTesting?.text == "second",
               "should accept new bubble after timeout")
    }
}

@MainActor
private final class MockSettings: InteractiveBubbleSettingsProviding {
    var isEnabled: Bool = true
    var activityLevel: ActivityLevel = .medium
    var minInterval: TimeInterval = 600
    var maxInterval: TimeInterval = 3600
    var optionWaitDuration: TimeInterval
    var silentPeriodStart: DateComponents = DateComponents(hour: 0, minute: 0)
    var silentPeriodEnd: DateComponents = DateComponents(hour: 9, minute: 0)
    var isAdvancedMode: Bool = false

    init(optionWaitDuration: TimeInterval = 15) {
        self.optionWaitDuration = optionWaitDuration
    }
}
