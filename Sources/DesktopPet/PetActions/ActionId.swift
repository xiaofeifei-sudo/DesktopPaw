public struct ActionId: RawRepresentable, Codable, Hashable, Equatable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard ActionStringValidator.isValid(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public static let idle = ActionId(rawValue: "idle_default")!

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let actionId = ActionId(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid action id: \(rawValue)"
            )
        }
        self = actionId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum ActionStringValidator {
    static let maximumLength = 64

    static func isValid(_ value: String) -> Bool {
        guard (1...maximumLength).contains(value.count) else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 97...122, 45, 46, 58, 95:
                return true
            default:
                return false
            }
        }
    }
}
