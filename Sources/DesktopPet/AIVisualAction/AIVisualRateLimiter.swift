import Foundation

public protocol AIVisualRateLimiting: Sendable {
    func canTrigger(source: AIVisualActionSource, at date: Date) -> Bool
    func recordTrigger(source: AIVisualActionSource, at date: Date)
    func nextAllowedTime(source: AIVisualActionSource, at date: Date) -> Date?
}

public final class AIVisualRateLimiter: AIVisualRateLimiting, @unchecked Sendable {
    public static let defaultAutonomousMinInterval: TimeInterval = 30 * 60

    private let lock = NSLock()
    private let autonomousMinInterval: TimeInterval
    private var lastAutonomousAt: Date?

    public init(autonomousMinInterval: TimeInterval = defaultAutonomousMinInterval) {
        self.autonomousMinInterval = autonomousMinInterval
    }

    public func canTrigger(source: AIVisualActionSource, at date: Date) -> Bool {
        guard isAutonomousSource(source) else { return true }
        lock.lock()
        defer { lock.unlock() }
        guard let lastAt = lastAutonomousAt else { return true }
        return date.timeIntervalSince(lastAt) >= autonomousMinInterval
    }

    public func recordTrigger(source: AIVisualActionSource, at date: Date) {
        guard isAutonomousSource(source) else { return }
        lock.lock()
        lastAutonomousAt = date
        lock.unlock()
    }

    public func nextAllowedTime(source: AIVisualActionSource, at date: Date) -> Date? {
        guard isAutonomousSource(source) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let lastAt = lastAutonomousAt else { return nil }
        let next = lastAt.addingTimeInterval(autonomousMinInterval)
        return next > date ? next : nil
    }

    public func setLastAutonomousAt(_ date: Date?) {
        lock.lock()
        lastAutonomousAt = date
        lock.unlock()
    }

    private func isAutonomousSource(_ source: AIVisualActionSource) -> Bool {
        source != .userRequest
    }
}
