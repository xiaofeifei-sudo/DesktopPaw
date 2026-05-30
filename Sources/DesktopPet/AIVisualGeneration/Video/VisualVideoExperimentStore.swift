import Foundation

public struct VisualVideoExperimentRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let petId: String
    public let model: HailuoModel
    public let promptDigest: String
    public let usedFirstFrame: Bool
    public let result: VisualVideoExperimentOutcome
    public let durationSeconds: Double?
    public let errorMessage: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        petId: String,
        model: HailuoModel,
        promptDigest: String,
        usedFirstFrame: Bool,
        result: VisualVideoExperimentOutcome,
        durationSeconds: Double? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.model = model
        self.promptDigest = promptDigest
        self.usedFirstFrame = usedFirstFrame
        self.result = result
        self.durationSeconds = durationSeconds
        self.errorMessage = errorMessage
        self.createdAt = createdAt
    }
}

public enum VisualVideoExperimentOutcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
    case firstFrameConsistent
    case firstFrameInconsistent
    case suitableForFrameExtraction
    case unsuitableForFrameExtraction
}

public struct VisualVideoExperimentSummary: Sendable, Equatable {
    public let totalExperiments: Int
    public let successCount: Int
    public let failureCount: Int
    public let firstFrameConsistentCount: Int
    public let suitableForFrameExtractionCount: Int
    public let averageDurationSeconds: Double?
    public let modelCounts: [String: Int]

    public init(
        totalExperiments: Int,
        successCount: Int,
        failureCount: Int,
        firstFrameConsistentCount: Int,
        suitableForFrameExtractionCount: Int,
        averageDurationSeconds: Double?,
        modelCounts: [String: Int]
    ) {
        self.totalExperiments = totalExperiments
        self.successCount = successCount
        self.failureCount = failureCount
        self.firstFrameConsistentCount = firstFrameConsistentCount
        self.suitableForFrameExtractionCount = suitableForFrameExtractionCount
        self.averageDurationSeconds = averageDurationSeconds
        self.modelCounts = modelCounts
    }
}

public protocol VisualVideoExperimentStoring: Sendable {
    var isExperimentEnabled: Bool { get }
    func setExperimentEnabled(_ enabled: Bool)
    func canGenerate(model: HailuoModel, on date: Date) -> Bool
    func record(_ record: VisualVideoExperimentRecord) throws
    func records(on date: Date) -> [VisualVideoExperimentRecord]
    func allRecords() -> [VisualVideoExperimentRecord]
    func summary() -> VisualVideoExperimentSummary
    func clearAll()
}

public final class VisualVideoExperimentStore: VisualVideoExperimentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private let maxRecords = 500

    private static let enabledKey = "visual-video-experiment-enabled"
    private static let recordsKey = "visual-video-experiment-records"

    public static let defaultDailyLimitPerModel = 2

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var isExperimentEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return userDefaults.bool(forKey: Self.enabledKey)
    }

    public func setExperimentEnabled(_ enabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        userDefaults.set(enabled, forKey: Self.enabledKey)
    }

    public func canGenerate(model: HailuoModel, on date: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let todayRecords = loadRecords().filter { record in
            record.model == model && Calendar.current.isDate(record.createdAt, inSameDayAs: date)
        }
        return todayRecords.count < Self.defaultDailyLimitPerModel
    }

    public func record(_ record: VisualVideoExperimentRecord) throws {
        lock.lock(); defer { lock.unlock() }
        var records = loadRecords()
        records.append(record)
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
        saveRecords(records)
    }

    public func records(on date: Date) -> [VisualVideoExperimentRecord] {
        lock.lock(); defer { lock.unlock() }
        return loadRecords().filter { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
    }

    public func allRecords() -> [VisualVideoExperimentRecord] {
        lock.lock(); defer { lock.unlock() }
        return loadRecords()
    }

    public func summary() -> VisualVideoExperimentSummary {
        lock.lock(); defer { lock.unlock() }
        let records = loadRecords()
        let successes = records.filter { $0.result == .succeeded || $0.result == .firstFrameConsistent || $0.result == .suitableForFrameExtraction }
        let failures = records.filter { $0.result == .failed }
        let consistent = records.filter { $0.result == .firstFrameConsistent }
        let suitable = records.filter { $0.result == .suitableForFrameExtraction }
        let durations = records.compactMap { $0.durationSeconds }
        let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
        var modelCounts: [String: Int] = [:]
        for record in records {
            modelCounts[record.model.rawValue, default: 0] += 1
        }
        return VisualVideoExperimentSummary(
            totalExperiments: records.count,
            successCount: successes.count,
            failureCount: failures.count,
            firstFrameConsistentCount: consistent.count,
            suitableForFrameExtractionCount: suitable.count,
            averageDurationSeconds: avgDuration,
            modelCounts: modelCounts
        )
    }

    public func clearAll() {
        lock.lock(); defer { lock.unlock() }
        userDefaults.removeObject(forKey: Self.recordsKey)
    }

    private func loadRecords() -> [VisualVideoExperimentRecord] {
        guard let data = userDefaults.data(forKey: Self.recordsKey) else { return [] }
        return (try? JSONDecoder().decode([VisualVideoExperimentRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [VisualVideoExperimentRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        userDefaults.set(data, forKey: Self.recordsKey)
    }
}
