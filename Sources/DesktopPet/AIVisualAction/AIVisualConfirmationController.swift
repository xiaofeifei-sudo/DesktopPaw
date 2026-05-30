import Foundation

public struct AIVisualConfirmationRequest: Identifiable, Sendable, Equatable {
    public let id: String
    public let candidate: AIVisualActionCandidate
    public let reason: AIVisualConfirmationReason
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        candidate: AIVisualActionCandidate,
        reason: AIVisualConfirmationReason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.candidate = candidate
        self.reason = reason
        self.createdAt = createdAt
    }
}

public protocol AIVisualConfirmationControlling: Sendable {
    var hasPreviousConfirmation: Bool { get }
    func createRequest(for candidate: AIVisualActionCandidate, reason: AIVisualConfirmationReason) -> AIVisualConfirmationRequest
    func pendingRequest(for id: String) -> AIVisualConfirmationRequest?
    func confirm(_ requestId: String) -> AIVisualActionCandidate?
    func reject(_ requestId: String)
    func clearPending()
}

public final class AIVisualConfirmationController: AIVisualConfirmationControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var _hasPreviousConfirmation: Bool
    private var pending: [String: AIVisualConfirmationRequest] = [:]

    public init(hasPreviousConfirmation: Bool = false) {
        self._hasPreviousConfirmation = hasPreviousConfirmation
    }

    public var hasPreviousConfirmation: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasPreviousConfirmation
    }

    public func createRequest(for candidate: AIVisualActionCandidate, reason: AIVisualConfirmationReason) -> AIVisualConfirmationRequest {
        let request = AIVisualConfirmationRequest(candidate: candidate, reason: reason)
        lock.lock()
        pending[request.id] = request
        lock.unlock()
        return request
    }

    public func pendingRequest(for id: String) -> AIVisualConfirmationRequest? {
        lock.lock()
        defer { lock.unlock() }
        return pending[id]
    }

    public func confirm(_ requestId: String) -> AIVisualActionCandidate? {
        lock.lock()
        guard let request = pending.removeValue(forKey: requestId) else {
            lock.unlock()
            return nil
        }
        _hasPreviousConfirmation = true
        lock.unlock()
        return request.candidate
    }

    public func reject(_ requestId: String) {
        lock.lock()
        pending.removeValue(forKey: requestId)
        lock.unlock()
    }

    public func clearPending() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
    }
}
