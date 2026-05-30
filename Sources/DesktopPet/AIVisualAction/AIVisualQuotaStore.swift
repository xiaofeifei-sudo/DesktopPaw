import Foundation

public protocol AIVisualQuotaStoring: Sendable {
    var config: AIVisualQuotaConfig { get }
    func loadUsage(petId: String, date: Date) -> AIVisualUsageSnapshot
    func canReserve(petId: String, source: AIVisualActionSource, at date: Date) -> AIVisualQuotaDecision
    func reserve(petId: String, actionId: String, source: AIVisualActionSource, at date: Date) throws
    func markSucceeded(actionId: String, providerId: String, assetId: String, at date: Date) throws
    func markFailed(actionId: String, providerId: String, errorCode: String, at date: Date) throws
}

public final class AIVisualQuotaStore: AIVisualQuotaStoring, @unchecked Sendable {
    public static let storeKey = "aiVisualQuotaData"

    public let config: AIVisualQuotaConfig
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: () -> Date

    private var data: AIVisualQuotaData

    public init(
        config: AIVisualQuotaConfig = .default,
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.config = config
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
        self.now = now
        self.data = AIVisualQuotaData()

        if let existing = userDefaults.data(forKey: Self.storeKey),
           let decoded = try? decoder.decode(AIVisualQuotaData.self, from: existing) {
            self.data = decoded
        }
    }

    public func loadUsage(petId: String, date: Date) -> AIVisualUsageSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let dayKey = Self.dayKey(date: date)
        let monthKey = Self.monthKey(date: date)
        let daily = data.daily[petId]?[dayKey] ?? AIVisualDailyData()

        let monthlyTotal: Int
        if let monthData = data.monthly[petId] {
            monthlyTotal = monthData[monthKey] ?? 0
        } else {
            monthlyTotal = 0
        }

        let pendingCount = data.records.values.filter {
            $0.petId == petId && $0.status == .reserved
        }.count

        return AIVisualUsageSnapshot(
            petId: petId,
            date: date,
            dailyAutonomousCount: daily.autonomousCount,
            dailyUserRequestCount: daily.userRequestCount,
            dailyTotalCount: daily.autonomousCount + daily.userRequestCount,
            monthlyTotalCount: monthlyTotal,
            lastAutonomousAt: daily.lastAutonomousAt,
            pendingCount: pendingCount
        )
    }

    public func canReserve(petId: String, source: AIVisualActionSource, at date: Date) -> AIVisualQuotaDecision {
        lock.lock()
        defer { lock.unlock() }

        return checkQuota(petId: petId, source: source, date: date)
    }

    public func reserve(petId: String, actionId: String, source: AIVisualActionSource, at date: Date) throws {
        lock.lock()
        defer { lock.unlock() }

        let decision = checkQuota(petId: petId, source: source, date: date)
        guard decision == .allowed else {
            throw AIVisualActionError.quotaExceeded
        }

        let dayKey = Self.dayKey(date: date)
        let monthKey = Self.monthKey(date: date)
        let isAutonomous = source != .userRequest

        if data.daily[petId] == nil {
            data.daily[petId] = [:]
        }
        if data.daily[petId]![dayKey] == nil {
            data.daily[petId]![dayKey] = AIVisualDailyData()
        }

        if isAutonomous {
            data.daily[petId]![dayKey]!.autonomousCount += 1
            data.daily[petId]![dayKey]!.lastAutonomousAt = date
        } else {
            data.daily[petId]![dayKey]!.userRequestCount += 1
        }

        if data.monthly[petId] == nil {
            data.monthly[petId] = [:]
        }
        data.monthly[petId]![monthKey, default: 0] += 1

        let record = AIVisualUsageRecord(
            id: actionId,
            source: source,
            petId: petId,
            reservedAt: date
        )
        data.records[actionId] = record

        persist()
    }

    public func markSucceeded(actionId: String, providerId: String, assetId: String, at date: Date) throws {
        lock.lock()
        defer { lock.unlock() }

        guard data.records[actionId] != nil else {
            throw AIVisualActionError.invalidCandidate(reason: "No reservation found for actionId: \(actionId)")
        }
        data.records[actionId]!.status = .succeeded
        data.records[actionId]!.providerId = providerId
        data.records[actionId]!.assetId = assetId
        data.records[actionId]!.completedAt = date

        persist()
    }

    public func markFailed(actionId: String, providerId: String, errorCode: String, at date: Date) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let record = data.records[actionId] else {
            throw AIVisualActionError.invalidCandidate(reason: "No reservation found for actionId: \(actionId)")
        }

        let dayKey = Self.dayKey(date: record.reservedAt)
        let monthKey = Self.monthKey(date: record.reservedAt)
        let petId = record.petId
        let isAutonomous = record.source != .userRequest

        if data.daily[petId]?[dayKey] != nil {
            if isAutonomous {
                data.daily[petId]![dayKey]!.autonomousCount = max(0, data.daily[petId]![dayKey]!.autonomousCount - 1)
            } else {
                data.daily[petId]![dayKey]!.userRequestCount = max(0, data.daily[petId]![dayKey]!.userRequestCount - 1)
            }
        }

        if data.monthly[petId]?[monthKey] != nil {
            data.monthly[petId]![monthKey] = max(0, data.monthly[petId]![monthKey]! - 1)
        }

        data.records[actionId]!.status = .failed
        data.records[actionId]!.providerId = providerId
        data.records[actionId]!.errorCode = errorCode
        data.records[actionId]!.completedAt = date

        persist()
    }

    // MARK: - Private

    private func checkQuota(petId: String, source: AIVisualActionSource, date: Date) -> AIVisualQuotaDecision {
        let dayKey = Self.dayKey(date: date)
        let monthKey = Self.monthKey(date: date)
        let daily = data.daily[petId]?[dayKey] ?? AIVisualDailyData()
        let monthlyTotal = data.monthly[petId]?[monthKey] ?? 0
        let dailyTotal = daily.autonomousCount + daily.userRequestCount
        let isAutonomous = source != .userRequest

        if monthlyTotal >= config.monthlyTotalLimit {
            return .monthlyTotalExceeded
        }

        if dailyTotal >= config.dailyTotalLimit {
            return .dailyTotalExceeded
        }

        if isAutonomous && daily.autonomousCount >= config.dailyAutonomousLimit {
            return .dailyAutonomousExceeded
        }

        if !isAutonomous && daily.userRequestCount >= config.dailyUserRequestLimit {
            return .dailyUserRequestExceeded
        }

        return .allowed
    }

    private func persist() {
        guard let encoded = try? encoder.encode(data) else { return }
        userDefaults.set(encoded, forKey: Self.storeKey)
    }

    static func dayKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func monthKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

struct AIVisualQuotaData: Codable, Equatable {
    var daily: [String: [String: AIVisualDailyData]] = [:]
    var monthly: [String: [String: Int]] = [:]
    var records: [String: AIVisualUsageRecord] = [:]
}

struct AIVisualDailyData: Codable, Equatable {
    var autonomousCount: Int = 0
    var userRequestCount: Int = 0
    var lastAutonomousAt: Date?
}
