import Foundation

public protocol AIVisualDiagnosticsStoring: Sendable {
    func record(_ event: AIVisualMetricEvent)
    func events(filter: ((AIVisualMetricEvent) -> Bool)?) -> [AIVisualMetricEvent]
    func eventsForAction(_ actionId: String) -> [AIVisualMetricEvent]
    func summary() -> AIVisualDiagnosticsSummary
    func exportAnonymousSummary() -> String
    func clearAll()
}

public final class AIVisualDiagnosticsStore: AIVisualDiagnosticsStoring, @unchecked Sendable {
    public static let storeKey = "aiVisualDiagnosticsData"
    private static let maxEvents = 1000

    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var eventsList: [AIVisualMetricEvent]

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
        self.eventsList = []

        if let existing = userDefaults.data(forKey: Self.storeKey),
           let decoded = try? decoder.decode([AIVisualMetricEvent].self, from: existing) {
            self.eventsList = decoded
        }
    }

    public func record(_ event: AIVisualMetricEvent) {
        lock.lock()
        defer { lock.unlock() }

        eventsList.append(event)
        if eventsList.count > Self.maxEvents {
            eventsList.removeFirst(eventsList.count - Self.maxEvents)
        }
        persist()
    }

    public func events(filter: ((AIVisualMetricEvent) -> Bool)? = nil) -> [AIVisualMetricEvent] {
        lock.lock()
        defer { lock.unlock() }

        guard let filter = filter else { return eventsList }
        return eventsList.filter(filter)
    }

    public func eventsForAction(_ actionId: String) -> [AIVisualMetricEvent] {
        lock.lock()
        defer { lock.unlock() }

        return eventsList.filter { $0.actionId == actionId }
    }

    public func summary() -> AIVisualDiagnosticsSummary {
        lock.lock()
        let events = eventsList
        lock.unlock()

        return Self.computeSummary(from: events)
    }

    public func exportAnonymousSummary() -> String {
        let s = summary()
        var lines: [String] = []
        lines.append("AI Visual Diagnostics Summary")
        lines.append("Total events: \(s.totalEvents)")
        lines.append("")
        lines.append("Event counts:")
        for (type, count) in s.eventCounts.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(type): \(count)")
        }
        lines.append("")
        lines.append("Generation: \(s.generationSuccessCount) succeeded, \(s.generationFailureCount) failed")
        if let avg = s.averageGenerationDurationSeconds {
            lines.append(String(format: "Avg generation duration: %.1fs", avg))
        }
        if s.generationSuccessCount + s.generationFailureCount > 0 {
            lines.append(String(format: "User restore rate: %.1f%% (restored / applied)", s.userRestoreRate * 100))
        }
        lines.append("Favorites: \(s.favoriteCount)")
        lines.append("Quota exceeded: \(s.quotaExceededCount)")
        lines.append("Safety rejected: \(s.safetyRejectedCount)")
        if !s.providerErrorCounts.isEmpty {
            lines.append("Provider errors:")
            for (code, count) in s.providerErrorCounts.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(code): \(count)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        eventsList.removeAll()
        persist()
    }

    // MARK: - Private

    private func persist() {
        guard let encoded = try? encoder.encode(eventsList) else { return }
        userDefaults.set(encoded, forKey: Self.storeKey)
    }

    static func computeSummary(from events: [AIVisualMetricEvent]) -> AIVisualDiagnosticsSummary {
        var eventCounts: [String: Int] = [:]
        for event in events {
            eventCounts[event.type.rawValue, default: 0] += 1
        }

        let succeeded = events.filter { $0.type == .generationSucceeded }
        let failed = events.filter { $0.type == .generationFailed }
        let applied = events.filter { $0.type == .overlayApplied }
        let restored = events.filter { $0.type == .overlayRestored }

        let durations = succeeded.compactMap { $0.durationSeconds }
        let avgDuration: Double? = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)

        let restoreRate: Double
        if applied.isEmpty {
            restoreRate = 0
        } else {
            restoreRate = Double(restored.count) / Double(applied.count)
        }

        var providerErrors: [String: Int] = [:]
        for event in failed {
            if let code = event.errorCode {
                providerErrors[code, default: 0] += 1
            }
        }

        return AIVisualDiagnosticsSummary(
            totalEvents: events.count,
            eventCounts: eventCounts,
            generationSuccessCount: succeeded.count,
            generationFailureCount: failed.count,
            averageGenerationDurationSeconds: avgDuration,
            userRestoreRate: restoreRate,
            favoriteCount: events.filter { $0.type == .favoriteCreated }.count,
            quotaExceededCount: events.filter { $0.type == .quotaExceeded }.count,
            safetyRejectedCount: events.filter { $0.type == .safetyRejected }.count,
            providerErrorCounts: providerErrors
        )
    }
}
