import Foundation
import DesktopPet

func runMicroDialogRuleCatalogTests() {
    let tests = MicroDialogRuleCatalogTests()
    tests.hungryTriggerReturnsFeedAndDismiss()
    tests.tiredTriggerReturnsSleepAndPet()
    tests.microDialogPromptReturnsDoneAndBusy()
    tests.unrelatedTriggerReturnsNil()
    tests.multipleTriggersMatchesHungryFirst()
    tests.allOptionsHaveNonEmptyTitles()
    tests.allOptionsHaveUniqueIds()
}

private struct MicroDialogRuleCatalogTests {
    private let catalog = MicroDialogRuleCatalog()

    func hungryTriggerReturnsFeedAndDismiss() {
        let phrase = BubblePhrase(id: "h", text: "hungry", triggers: [.hungry], canStartMicroDialog: true)
        let options = catalog.options(for: phrase)

        expect(options != nil, "hungry phrase should return options")
        expect(options!.count == 2, "hungry should have 2 options")
        expect(options![0].command == .feed, "first option should be feed")
        if case .dismiss = options![1].command {
            // expected
        } else {
            fail("second option should be dismiss")
        }
    }

    func tiredTriggerReturnsSleepAndPet() {
        let phrase = BubblePhrase(id: "t", text: "tired", triggers: [.tired], canStartMicroDialog: true)
        let options = catalog.options(for: phrase)

        expect(options != nil, "tired phrase should return options")
        expect(options!.count == 2, "tired should have 2 options")
        expect(options![0].command == .sleep, "first option should be sleep")
        expect(options![1].command == .pet, "second option should be pet")
    }

    func microDialogPromptReturnsDoneAndBusy() {
        let phrase = BubblePhrase(id: "p", text: "prompt", triggers: [.microDialogPrompt], canStartMicroDialog: true)
        let options = catalog.options(for: phrase)

        expect(options != nil, "prompt phrase should return options")
        expect(options!.count == 2, "prompt should have 2 options")
        expect(options![0].command == .showBubble(.idle), "first option should show idle bubble")
        if case .dismiss = options![1].command {
            // expected
        } else {
            fail("second option should be dismiss")
        }
    }

    func unrelatedTriggerReturnsNil() {
        let phrase = BubblePhrase(id: "i", text: "idle", triggers: [.idle], canStartMicroDialog: true)
        let options = catalog.options(for: phrase)

        expect(options == nil, "unrelated trigger should return nil")
    }

    func multipleTriggersMatchesHungryFirst() {
        let phrase = BubblePhrase(id: "combo", text: "combo", triggers: [.hungry, .tired], canStartMicroDialog: true)
        let options = catalog.options(for: phrase)

        expect(options != nil, "multi-trigger phrase should return options")
        expect(options![0].command == .feed, "should match hungry first (hungry checked before tired)")
    }

    func allOptionsHaveNonEmptyTitles() {
        let allPhrases = [
            BubblePhrase(id: "h", text: "hungry", triggers: [.hungry]),
            BubblePhrase(id: "t", text: "tired", triggers: [.tired]),
            BubblePhrase(id: "p", text: "prompt", triggers: [.microDialogPrompt])
        ]

        for phrase in allPhrases {
            let options = catalog.options(for: phrase)!
            for option in options {
                expect(!option.title.isEmpty, "option \(option.id.rawValue) should have non-empty title")
            }
        }
    }

    func allOptionsHaveUniqueIds() {
        let hungryOptions = catalog.options(for: BubblePhrase(id: "h", text: "", triggers: [.hungry]))!
        let tiredOptions = catalog.options(for: BubblePhrase(id: "t", text: "", triggers: [.tired]))!
        let promptOptions = catalog.options(for: BubblePhrase(id: "p", text: "", triggers: [.microDialogPrompt]))!

        let allIds = (hungryOptions + tiredOptions + promptOptions).map { $0.id.rawValue }
        let uniqueIds = Set(allIds)
        expect(allIds.count == uniqueIds.count, "all option ids should be unique across catalogs")
    }
}
