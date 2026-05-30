import Foundation

public enum BubbleFrequency: String, Codable, CaseIterable, Sendable, Equatable {
    case quiet
    case normal
    case expressive

    public static let `default`: BubbleFrequency = .normal
}
