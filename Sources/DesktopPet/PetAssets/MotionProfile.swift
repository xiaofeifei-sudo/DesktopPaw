import Foundation

public enum MotionKind: String, Codable, Equatable, Sendable {
    case none
    case bob
    case bounce
    case shake
    case jump
    case tilt
    case drift
}

public struct StateMotion: Codable, Equatable, Sendable {
    public let kind: MotionKind
    public let amplitude: Double
    public let durationMs: Int
    public let loop: Bool

    public init(kind: MotionKind, amplitude: Double, durationMs: Int, loop: Bool) {
        self.kind = kind
        self.amplitude = amplitude
        self.durationMs = durationMs
        self.loop = loop
    }
}

public struct MotionProfile: Codable, Equatable, Sendable {
    public let stateMotions: [PetState: StateMotion]

    public init(stateMotions: [PetState: StateMotion]) {
        self.stateMotions = stateMotions
    }

    public func motion(for state: PetState) -> StateMotion {
        stateMotions[state] ?? StateMotion(kind: .none, amplitude: 0, durationMs: 0, loop: false)
    }

    private enum CodingKeys: String, CodingKey {
        case stateMotions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([String: StateMotion].self, forKey: .stateMotions)
        self.stateMotions = try Dictionary(uniqueKeysWithValues: raw.map { key, motion in
            guard let state = PetState(rawValue: key) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .stateMotions,
                    in: container,
                    debugDescription: "Unknown pet state in motion profile: \(key)"
                )
            }
            return (state, motion)
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let raw = Dictionary(uniqueKeysWithValues: stateMotions.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .stateMotions)
    }
}

public enum MotionProfileDefaults {
    public static func singleImageDefault() -> MotionProfile {
        MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .bob, amplitude: 4, durationMs: 1800, loop: true),
            .walking: StateMotion(kind: .drift, amplitude: 6, durationMs: 1200, loop: true),
            .sleeping: StateMotion(kind: .bob, amplitude: 2, durationMs: 2400, loop: true),
            .happy: StateMotion(kind: .bounce, amplitude: 12, durationMs: 480, loop: false),
            .eating: StateMotion(kind: .shake, amplitude: 4, durationMs: 360, loop: false),
            .jumping: StateMotion(kind: .jump, amplitude: 18, durationMs: 420, loop: false),
            .dragging: StateMotion(kind: .tilt, amplitude: 6, durationMs: 240, loop: false)
        ])
    }
}
