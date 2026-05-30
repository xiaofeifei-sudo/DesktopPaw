public enum PetState: String, Codable, CaseIterable, Equatable, Sendable {
    case idle
    case walking
    case sleeping
    case happy
    case eating
    case jumping
    case dragging
}
