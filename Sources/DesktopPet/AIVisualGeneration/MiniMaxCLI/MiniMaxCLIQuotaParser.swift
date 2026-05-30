import Foundation

public struct MiniMaxAuthStatus: Sendable, Equatable {
    public let isAuthenticated: Bool
    public let method: String?

    public init(isAuthenticated: Bool, method: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.method = method
    }
}

public struct MiniMaxModelQuota: Sendable, Equatable {
    public let modelName: String
    public let intervalTotal: Int
    public let intervalUsed: Int
    public let weeklyTotal: Int
    public let weeklyUsed: Int

    public init(
        modelName: String,
        intervalTotal: Int,
        intervalUsed: Int,
        weeklyTotal: Int,
        weeklyUsed: Int
    ) {
        self.modelName = modelName
        self.intervalTotal = intervalTotal
        self.intervalUsed = intervalUsed
        self.weeklyTotal = weeklyTotal
        self.weeklyUsed = weeklyUsed
    }

    public var intervalRemaining: Int { max(intervalTotal - intervalUsed, 0) }
    public var weeklyRemaining: Int { max(weeklyTotal - weeklyUsed, 0) }
}

public enum MiniMaxCLIQuotaParser {

    public static let imageModelName = "image-01"

    public static func parseAuthStatus(from output: String) -> MiniMaxAuthStatus {
        guard let data = output.data(using: .utf8) else {
            return MiniMaxAuthStatus(isAuthenticated: false)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return MiniMaxAuthStatus(isAuthenticated: false)
        }
        let method = json["method"] as? String
        let hasKey = json["key"] != nil
        let hasOAuth = json["token_expires"] != nil || method == "oauth"
        return MiniMaxAuthStatus(isAuthenticated: hasKey || hasOAuth, method: method)
    }

    public static func parseQuota(from output: String) -> [MiniMaxModelQuota] {
        guard let data = output.data(using: .utf8) else { return [] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        guard let remains = json["model_remains"] as? [[String: Any]] else { return [] }

        return remains.compactMap { entry -> MiniMaxModelQuota? in
            guard let name = entry["model_name"] as? String,
                  let total = entry["current_interval_total_count"] as? Int,
                  let reportedRemaining = entry["current_interval_usage_count"] as? Int,
                  let wTotal = entry["current_weekly_total_count"] as? Int,
                  let reportedWeeklyRemaining = entry["current_weekly_usage_count"] as? Int else {
                return nil
            }
            // MiniMax remains endpoint uses *_usage_count names, but real image-01
            // verification shows the value decreases after generation, so treat it
            // as the remaining count and normalize to the app's used/remaining API.
            let used = max(total - reportedRemaining, 0)
            let wUsed = max(wTotal - reportedWeeklyRemaining, 0)
            return MiniMaxModelQuota(
                modelName: name,
                intervalTotal: total,
                intervalUsed: used,
                weeklyTotal: wTotal,
                weeklyUsed: wUsed
            )
        }
    }

    public static func parseImageQuota(from output: String) -> MiniMaxModelQuota? {
        parseQuota(from: output).first { $0.modelName == imageModelName }
    }
}
