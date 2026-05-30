import Foundation
import DesktopPet

func runMicroDialogServiceTests() {
    let tests = MicroDialogServiceTests()
    tests.hungryPhraseGeneratesDialog()
    tests.tiredPhraseGeneratesDialog()
    tests.promptPhraseGeneratesDialog()
    tests.nonMicroDialogPhraseReturnsNil()
    tests.quietModeBlocksDialogGeneration()
    tests.disabledMicroDialogsReturnsNil()
    tests.commandReturnsCorrectOptionCommand()
    tests.expiredDialogReturnsNoCommand()
    tests.dismissClearsActiveDialog()
    tests.dismissCommandProducesNoNegativeFeedback()
    tests.feedOptionReturnsFeedCommand()
    tests.petOptionReturnsPetCommand()
    tests.sleepOptionReturnsSleepCommand()
    tests.dialogHasAtMostThreeOptions()
}

private struct MicroDialogServiceTests {
    private let now = Date()

    private func makeService(
        quietModePolicy: any QuietModeEvaluating = QuietModePolicy()
    ) -> MicroDialogService {
        MicroDialogService(
            ruleCatalog: MicroDialogRuleCatalog(),
            quietModePolicy: quietModePolicy,
            dialogDuration: 30
        )
    }

    private func makeContext(
        preferences: CompanionPreferences = CompanionPreferences()
    ) -> CompanionContext {
        CompanionContext(
            petId: "test-pet",
            petDisplayName: "Test Pet",
            runtimeState: .defaultState(at: Date()),
            relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
            preferences: preferences,
            timeSlots: [.morning]
        )
    }

    func hungryPhraseGeneratesDialog() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()

        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog != nil, "hungry phrase should generate a dialog")
        expect(dialog!.options.count == 2, "hungry dialog should have 2 options")
        expect(dialog!.promptPhraseId == "hungry-0", "dialog should reference the prompt phrase id")
    }

    func tiredPhraseGeneratesDialog() {
        let service = makeService()
        let phrase = BubblePhrase(id: "tired-0", text: "困了", triggers: [.tired], canStartMicroDialog: true)
        let context = makeContext()

        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog != nil, "tired phrase should generate a dialog")
        expect(dialog!.options.count == 2, "tired dialog should have 2 options")
    }

    func promptPhraseGeneratesDialog() {
        let service = makeService()
        let phrase = BubblePhrase(id: "prompt-0", text: "你忙完了吗？", triggers: [.microDialogPrompt], canStartMicroDialog: true)
        let context = makeContext()

        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog != nil, "prompt phrase should generate a dialog")
        expect(dialog!.options.count == 2, "prompt dialog should have 2 options")
    }

    func nonMicroDialogPhraseReturnsNil() {
        let service = makeService()
        let phrase = BubblePhrase(id: "idle-0", text: "嗯", triggers: [.idle], canStartMicroDialog: false)
        let context = makeContext()

        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog == nil, "non-micro-dialog phrase should return nil")
    }

    func quietModeBlocksDialogGeneration() {
        struct AlwaysQuiet: QuietModeEvaluating {
            func quietState(preferences: CompanionPreferences, at date: Date) -> QuietModeState {
                .temporary(until: date.addingTimeInterval(3600))
            }
        }

        let service = makeService(quietModePolicy: AlwaysQuiet())
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()

        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog == nil, "quiet mode should block dialog generation")
    }

    func disabledMicroDialogsReturnsNil() {
        let service = makeService()
        var prefs = CompanionPreferences()
        prefs.microDialogsEnabled = false
        let context = makeContext(preferences: prefs)

        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let dialog = service.dialog(for: phrase, context: context, now: now)

        expect(dialog == nil, "disabled micro dialogs should return nil")
    }

    func commandReturnsCorrectOptionCommand() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()
        let dialog = service.dialog(for: phrase, context: context, now: now)
        _ = dialog

        let feedOptionId = MicroDialogOptionId(rawValue: "hungry-feed")
        let command = service.command(for: feedOptionId, now: now)

        expect(command == .feed, "should return feed command for feed option")
    }

    func expiredDialogReturnsNoCommand() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        let afterExpiry = now.addingTimeInterval(31)
        let feedOptionId = MicroDialogOptionId(rawValue: "hungry-feed")
        let command = service.command(for: feedOptionId, now: afterExpiry)

        expect(command == nil, "expired dialog should return no command")
    }

    func dismissClearsActiveDialog() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        service.dismissActiveDialog()

        let feedOptionId = MicroDialogOptionId(rawValue: "hungry-feed")
        let command = service.command(for: feedOptionId, now: now)

        expect(command == nil, "dismissed dialog should return no command")
    }

    func dismissCommandProducesNoNegativeFeedback() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        let dismissOptionId = MicroDialogOptionId(rawValue: "hungry-dismiss")
        let command = service.command(for: dismissOptionId, now: now)

        if case .dismiss = command {
            // expected - dismiss with no negative trigger
        } else {
            fail("dismiss option should return dismiss command, got \(String(describing: command))")
        }
    }

    func feedOptionReturnsFeedCommand() {
        let service = makeService()
        let phrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        let command = service.command(for: MicroDialogOptionId(rawValue: "hungry-feed"), now: now)
        expect(command == .feed, "feed option should return feed command")
    }

    func petOptionReturnsPetCommand() {
        let service = makeService()
        let phrase = BubblePhrase(id: "tired-0", text: "困了", triggers: [.tired], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        let command = service.command(for: MicroDialogOptionId(rawValue: "tired-pet"), now: now)
        expect(command == .pet, "pet option should return pet command")
    }

    func sleepOptionReturnsSleepCommand() {
        let service = makeService()
        let phrase = BubblePhrase(id: "tired-0", text: "困了", triggers: [.tired], canStartMicroDialog: true)
        let context = makeContext()
        _ = service.dialog(for: phrase, context: context, now: now)

        let command = service.command(for: MicroDialogOptionId(rawValue: "tired-sleep"), now: now)
        expect(command == .sleep, "sleep option should return sleep command")
    }

    func dialogHasAtMostThreeOptions() {
        let service = makeService()
        let context = makeContext()

        let hungryPhrase = BubblePhrase(id: "hungry-0", text: "有点饿", triggers: [.hungry], canStartMicroDialog: true)
        let tiredPhrase = BubblePhrase(id: "tired-0", text: "困了", triggers: [.tired], canStartMicroDialog: true)
        let promptPhrase = BubblePhrase(id: "prompt-0", text: "你忙完了吗？", triggers: [.microDialogPrompt], canStartMicroDialog: true)

        for phrase in [hungryPhrase, tiredPhrase, promptPhrase] {
            let dialog = service.dialog(for: phrase, context: context, now: now)
            expect(dialog != nil, "should generate dialog for \(phrase.id)")
            expect(dialog!.options.count <= MicroDialog.maxOptionCount, "dialog should have at most \(MicroDialog.maxOptionCount) options")
        }
    }
}
