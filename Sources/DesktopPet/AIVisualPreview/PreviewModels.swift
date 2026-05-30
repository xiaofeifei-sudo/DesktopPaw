import Foundation

public enum PreviewFeedbackType: String, CaseIterable, Codable, Sendable {
    case notLikeOriginal
    case styleWrong
    case colorWrong
    case accessoryLost
    case goodDirection

    public var displayText: String {
        switch self {
        case .notLikeOriginal: return "不像原图"
        case .styleWrong: return "画风不对"
        case .colorWrong: return "颜色不对"
        case .accessoryLost: return "饰品丢了"
        case .goodDirection: return "很好，保留这种方向"
        }
    }
}

public struct PreviewActions: Sendable {
    public let onApply: @Sendable () async -> Void
    public let onDiscard: @Sendable () async -> Void
    public let onRetry: @Sendable () async -> Void
    public let onFeedback: @Sendable (PreviewFeedbackType) async -> Void

    public init(
        onApply: @escaping @Sendable () async -> Void,
        onDiscard: @escaping @Sendable () async -> Void,
        onRetry: @escaping @Sendable () async -> Void,
        onFeedback: @escaping @Sendable (PreviewFeedbackType) async -> Void
    ) {
        self.onApply = onApply
        self.onDiscard = onDiscard
        self.onRetry = onRetry
        self.onFeedback = onFeedback
    }
}
