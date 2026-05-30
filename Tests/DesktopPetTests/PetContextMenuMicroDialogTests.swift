import AppKit
import Foundation
import DesktopPet

@MainActor
func runPetContextMenuMicroDialogTests() {
    let tests = PetContextMenuMicroDialogTests()
    tests.contextMenuIncludesMicroDialogOptionsWhenActive()
    tests.contextMenuExcludesMicroDialogOptionsWhenNone()
    tests.contextMenuExcludesMicroDialogOptionsWhenExpired()
}

@MainActor
private struct PetContextMenuMicroDialogTests {
    func contextMenuIncludesMicroDialogOptionsWhenActive() {
        let harness = makeHarness()
        let options = [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "opt-1"), title: "Feed it", command: .feed),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "opt-2"), title: "Wait", command: .dismiss(replyTrigger: nil))
        ]
        harness.microDialogService.setActiveDialog(makeDialog(options: options))

        let menu = harness.petWindow.buildContextMenu()

        let feedItem = menu.items.first(where: { $0.title == "Feed it" })
        expect(feedItem != nil, "context menu should include 'Feed it' option from micro dialog")
        let waitItem = menu.items.first(where: { $0.title == "Wait" })
        expect(waitItem != nil, "context menu should include 'Wait' option from micro dialog")
    }

    func contextMenuExcludesMicroDialogOptionsWhenNone() {
        let harness = makeHarness()
        let menu = harness.petWindow.buildContextMenu()

        let hasDialogOptions = menu.items.contains { item in
            item.title == "Feed it" || item.title == "Wait"
        }
        expect(!hasDialogOptions, "context menu should not include micro dialog options when none active")
    }

    func contextMenuExcludesMicroDialogOptionsWhenExpired() {
        let harness = makeHarness()
        let expiredDialog = MicroDialog(
            id: "dlg-exp",
            promptPhraseId: "phrase-1",
            options: [MicroDialogOption(id: MicroDialogOptionId(rawValue: "opt-1"), title: "Feed it", command: .feed)],
            expiresAt: Date().addingTimeInterval(-60)
        )
        harness.microDialogService.setActiveDialog(expiredDialog)

        let menu = harness.petWindow.buildContextMenu()

        let feedItem = menu.items.first(where: { $0.title == "Feed it" })
        expect(feedItem == nil, "context menu should not include expired micro dialog options")
    }

    private func makeDialog(options: [MicroDialogOption]) -> MicroDialog {
        MicroDialog(
            id: "dlg-1",
            promptPhraseId: "phrase-1",
            options: options,
            expiresAt: Date().addingTimeInterval(60)
        )
    }

    private func makeHarness() -> ContextMenuMicroDialogHarness {
        let microDialogService = MicroDialogService()
        let petWindow = PetWindowController(
            frameSize: CGSize(width: 128, height: 128),
            initiallyVisible: true,
            frameStore: UserDefaultsPetWindowFrameStore()
        )
        petWindow.menuStateProvider = {
            AppMenuState(isPetVisible: true, isSleeping: false, isLaunchAtLoginEnabled: false)
        }
        petWindow.microDialogOptionsProvider = { [microDialogService] in
            microDialogService.activeDialogOptions(now: Date())
        }
        return ContextMenuMicroDialogHarness(
            petWindow: petWindow,
            microDialogService: microDialogService
        )
    }
}

@MainActor
private struct ContextMenuMicroDialogHarness {
    let petWindow: PetWindowController
    let microDialogService: MicroDialogService
}
