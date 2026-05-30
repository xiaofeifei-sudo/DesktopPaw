import AppKit
import DesktopPet
import Foundation

private final class Flag: @unchecked Sendable {
    var value = false
}

private final class FeedbackCapture: @unchecked Sendable {
    var type: PreviewFeedbackType?
}

@MainActor
func runPreviewPresenterTests() async throws {
    let tests = PreviewPresenterTests()
    try tests.previewFeedbackTypeDisplayText()
    try await tests.previewActionsCallbacks()
    try await tests.presenterDismissBeforeShowIsNoOp()
}

@MainActor
private struct PreviewPresenterTests {

    // MARK: - Model Tests

    func previewFeedbackTypeDisplayText() throws {
        let expectations: [PreviewFeedbackType: String] = [
            .notLikeOriginal: "不像原图",
            .styleWrong: "画风不对",
            .colorWrong: "颜色不对",
            .accessoryLost: "饰品丢了",
            .goodDirection: "很好，保留这种方向",
        ]
        for (type, text) in expectations {
            try expect(type.displayText == text, "\(type) displayText should be '\(text)'")
        }
    }

    func previewActionsCallbacks() async throws {
        let applyCalled = Flag()
        let discardCalled = Flag()
        let retryCalled = Flag()
        let feedbackCapture = FeedbackCapture()

        let actions = PreviewActions(
            onApply: { applyCalled.value = true },
            onDiscard: { discardCalled.value = true },
            onRetry: { retryCalled.value = true },
            onFeedback: { type in feedbackCapture.type = type }
        )

        await actions.onApply()
        try expect(applyCalled.value, "onApply should be invoked")

        await actions.onDiscard()
        try expect(discardCalled.value, "onDiscard should be invoked")

        await actions.onRetry()
        try expect(retryCalled.value, "onRetry should be invoked")

        await actions.onFeedback(.colorWrong)
        try expect(feedbackCapture.type == .colorWrong, "onFeedback should receive the correct type")

        await actions.onFeedback(.styleWrong)
        try expect(feedbackCapture.type == .styleWrong, "onFeedback should update to latest type")
    }

    func presenterDismissBeforeShowIsNoOp() async throws {
        let presenter = PreviewPresenter()
        presenter.dismissPreview()
        try expect(true, "dismissPreview before showPreview should not crash")
    }
}

private func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) throws {
    if !condition {
        throw TestFailure(message: message, file: file, line: line)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: StaticString
    let line: UInt
    var description: String { "[FAIL] \(message) (\(file):\(line))" }
}
