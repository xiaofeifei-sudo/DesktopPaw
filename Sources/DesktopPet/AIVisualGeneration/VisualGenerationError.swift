import Foundation

public enum VisualGenerationError: Error, Sendable, Equatable {
    case notConfigured(providerId: String)
    case timeout(providerId: String)
    case quotaExceeded(providerId: String)
    case safetyRejected(reason: String)
    case network(providerId: String, underlying: String)
    case invalidOutput(providerId: String, reason: String)
    case cancelled
    case unknown(providerId: String, underlying: String)

    public var providerId: String {
        switch self {
        case .notConfigured(let id), .timeout(let id), .quotaExceeded(let id),
             .network(let id, _), .invalidOutput(let id, _), .unknown(let id, _):
            return id
        case .safetyRejected, .cancelled:
            return ""
        }
    }
}
