public struct ActionTag: RawRepresentable, Codable, Hashable, Equatable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard ActionStringValidator.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public var prefix: ActionTagPrefix? {
        for prefix in ActionTagPrefix.allCases where rawValue.hasPrefix(prefix.marker) {
            return prefix
        }
        return nil
    }

    public var value: String? {
        if let prefix {
            let start = rawValue.index(rawValue.startIndex, offsetBy: prefix.marker.count)
            return String(rawValue[start...])
        }

        guard let delimiter = rawValue.firstIndex(where: { $0 == ":" || $0 == "." }) else {
            return nil
        }

        let start = rawValue.index(after: delimiter)
        return String(rawValue[start...])
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let tag = ActionTag(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid action tag: \(rawValue)"
            )
        }
        self = tag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum ActionTagPrefix: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case mood
    case after
    case time

    public var marker: String {
        switch self {
        case .mood:
            return "mood:"
        case .after:
            return "after."
        case .time:
            return "time."
        }
    }
}
