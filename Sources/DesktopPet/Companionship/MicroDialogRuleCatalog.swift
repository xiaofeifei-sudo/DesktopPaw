import Foundation

public struct MicroDialogRuleCatalog: Sendable {
    public init() {}

    public func options(for phrase: BubblePhrase) -> [MicroDialogOption]? {
        if phrase.triggers.contains(.hungry) {
            return hungryOptions()
        }
        if phrase.triggers.contains(.tired) {
            return tiredOptions()
        }
        if phrase.triggers.contains(.microDialogPrompt) {
            return promptOptions()
        }
        return nil
    }

    private func hungryOptions() -> [MicroDialogOption] {
        [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "hungry-feed"), title: "Feed", command: .feed),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "hungry-dismiss"), title: "Later", command: .dismiss(replyTrigger: nil))
        ]
    }

    private func tiredOptions() -> [MicroDialogOption] {
        [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "tired-sleep"), title: "Let it sleep", command: .sleep),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "tired-pet"), title: "Pet it", command: .pet)
        ]
    }

    private func promptOptions() -> [MicroDialogOption] {
        [
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "prompt-done"), title: "Done", command: .showBubble(.idle)),
            MicroDialogOption(id: MicroDialogOptionId(rawValue: "prompt-busy"), title: "Still busy", command: .dismiss(replyTrigger: nil))
        ]
    }
}
