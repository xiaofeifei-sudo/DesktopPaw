import Foundation

public enum MicroDialogCommand: Codable, Equatable, Sendable {
    case pet
    case feed
    case sleep
    case dismiss(replyTrigger: BubbleTrigger?)
    case showBubble(BubbleTrigger)
}
