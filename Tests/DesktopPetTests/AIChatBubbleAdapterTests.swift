import Foundation
import DesktopPet

@MainActor
func runAIChatBubbleAdapterTests() {
    let tests = AIChatBubbleAdapterTests()
    tests.adaptReturnsNilForNil()
    tests.adaptReturnsNilForEmpty()
    tests.adaptReturnsNilForWhitespace()
    tests.adaptReturnsShortTextUnchanged()
    tests.adaptTruncatesLongCJKText()
    tests.truncateReturnsShortTextUnchanged()
    tests.truncateHandlesExactLimit()
    tests.truncateAddsEllipsisForOverflow()
    tests.truncatePreservesNonCJKCharacters()
    tests.cjkCountReturnsCorrectCount()
    tests.cjkCountIgnoresNonCJK()
}

@MainActor
private struct AIChatBubbleAdapterTests {
    func adaptReturnsNilForNil() {
        let result = AIChatBubbleAdapter.adapt(nil)
        expect(result == nil, "adapt should return nil for nil input")
    }

    func adaptReturnsNilForEmpty() {
        let result = AIChatBubbleAdapter.adapt("")
        expect(result == nil, "adapt should return nil for empty string")
    }

    func adaptReturnsNilForWhitespace() {
        let result = AIChatBubbleAdapter.adapt("   \n\t  ")
        expect(result == nil, "adapt should return nil for whitespace-only string")
    }

    func adaptReturnsShortTextUnchanged() {
        let result = AIChatBubbleAdapter.adapt("你好呀")
        expect(result == "你好呀", "adapt should return short text unchanged")
    }

    func adaptTruncatesLongCJKText() {
        let long = "今天天气真好想出去玩呀哈哈" // 13 CJK chars
        let result = AIChatBubbleAdapter.adapt(long)
        expect(result != nil, "adapt should return non-nil for long text")
        expect(result! != long, "adapt should truncate long text")
        expect(result!.hasSuffix("…"), "truncated text should end with ellipsis")
    }

    func truncateReturnsShortTextUnchanged() {
        let text = "你好"
        let result = AIChatBubbleAdapter.truncate(text)
        expect(result == "你好", "truncate should return short text unchanged")
    }

    func truncateHandlesExactLimit() {
        let text = "今天天气真好想"
        let result = AIChatBubbleAdapter.truncate(text)
        expect(result == text, "truncate should return text at exact CJK limit unchanged")
    }

    func truncateAddsEllipsisForOverflow() {
        let text = "今天天气真好想出去玩呀哈啊"
        let result = AIChatBubbleAdapter.truncate(text)
        expect(result.hasSuffix("…"), "truncate should add ellipsis for overflow")
    }

    func truncatePreservesNonCJKCharacters() {
        let text = "你好world再见"
        let result = AIChatBubbleAdapter.truncate(text, maxLength: 3)
        expect(result != nil, "should handle mixed text")
        expect(result.contains("你好"), "should preserve initial CJK characters")
    }

    func cjkCountReturnsCorrectCount() {
        let count = AIChatBubbleAdapter.cjkCount("你好世界")
        expect(count == 4, "cjkCount should count 4 CJK characters")
    }

    func cjkCountIgnoresNonCJK() {
        let count = AIChatBubbleAdapter.cjkCount("你好！world")
        expect(count == 2, "cjkCount should only count CJK characters, not punctuation or ASCII")
    }
}
