import Foundation
import DesktopPet

func runInteractionSummaryTests() {
    let tests = InteractionSummaryTests()
    tests.defaultsToEmptyCountsAndNoRecentBubbleText()
    tests.recordsRecentBubbleTextsWithNewestEntriesKept()
}

private struct InteractionSummaryTests {
    func defaultsToEmptyCountsAndNoRecentBubbleText() {
        let summary = InteractionSummary()

        expect(summary.todayPetCount == 0, "summary should start with zero pet interactions")
        expect(summary.todayFeedCount == 0, "summary should start with zero feed interactions")
        expect(summary.todayActionPlayCount == 0, "summary should start with zero action interactions")
        expect(summary.todayMicroDialogCount == 0, "summary should start with zero micro dialog interactions")
        expect(summary.recentBubbleTexts.isEmpty, "summary should start without recent bubble texts")
        expect(summary.lastBubbleText == nil, "summary should not expose a last bubble text when empty")
    }

    func recordsRecentBubbleTextsWithNewestEntriesKept() {
        var summary = InteractionSummary()

        summary.recordBubbleText("你好")
        summary.recordBubbleText("")
        summary.recordBubbleText("欢迎回来")
        summary.recordBubbleText("今天也在", limit: 2)

        expect(summary.recentBubbleTexts == ["欢迎回来", "今天也在"], "summary should keep newest non-empty bubble texts within limit")
        expect(summary.lastBubbleText == "今天也在", "summary should expose newest bubble text")
    }
}
