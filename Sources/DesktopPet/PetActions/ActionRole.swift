public enum ActionRole: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case idle
    case walking
    case sleeping
    case happy
    case eating
    case jumping
    case dragging

    public var legacyState: PetState {
        switch self {
        case .idle:
            return .idle
        case .walking:
            return .walking
        case .sleeping:
            return .sleeping
        case .happy:
            return .happy
        case .eating:
            return .eating
        case .jumping:
            return .jumping
        case .dragging:
            return .dragging
        }
    }

    public init(legacyState: PetState) {
        switch legacyState {
        case .idle:
            self = .idle
        case .walking:
            self = .walking
        case .sleeping:
            self = .sleeping
        case .happy:
            self = .happy
        case .eating:
            self = .eating
        case .jumping:
            self = .jumping
        case .dragging:
            self = .dragging
        }
    }

    public static let required: Set<ActionRole> = [.idle, .dragging]
    public static let recommended: Set<ActionRole> = [.walking, .sleeping, .happy, .eating, .jumping]
}
