public struct PetActionOverride: Codable, Equatable, Sendable {
    public let actionId: ActionId
    public let displayName: String?
    public let tags: [ActionTag]?
    public let role: ActionRole?
    public let frameDurationsMs: [Int]?

    public init(
        actionId: ActionId,
        displayName: String? = nil,
        tags: [ActionTag]? = nil,
        role: ActionRole? = nil,
        frameDurationsMs: [Int]? = nil
    ) {
        self.actionId = actionId
        self.displayName = displayName
        self.tags = tags
        self.role = role
        self.frameDurationsMs = frameDurationsMs
    }
}

public struct PetActionOverrideSet: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let overrideSchemaVersion: Int
    public let petId: String
    public let overrides: [PetActionOverride]

    public init(
        overrideSchemaVersion: Int = PetActionOverrideSet.currentSchemaVersion,
        petId: String,
        overrides: [PetActionOverride]
    ) {
        self.overrideSchemaVersion = overrideSchemaVersion
        self.petId = petId
        self.overrides = overrides
    }

    public func override(for actionId: ActionId) -> PetActionOverride? {
        overrides.first { $0.actionId == actionId }
    }

    public var overridesByActionId: [ActionId: PetActionOverride] {
        var result: [ActionId: PetActionOverride] = [:]
        for override in overrides where result[override.actionId] == nil {
            result[override.actionId] = override
        }
        return result
    }

    public static func == (lhs: PetActionOverrideSet, rhs: PetActionOverrideSet) -> Bool {
        lhs.overrideSchemaVersion == rhs.overrideSchemaVersion &&
            lhs.petId == rhs.petId &&
            lhs.overridesByActionId == rhs.overridesByActionId
    }

    private enum CodingKeys: String, CodingKey {
        case overrideSchemaVersion
        case petId
        case actions
        case overrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let overrideSchemaVersion = try container.decode(Int.self, forKey: .overrideSchemaVersion)
        let petId = try container.decode(String.self, forKey: .petId)
        let payloads = try container.decodeIfPresent([String: PetActionOverridePayload].self, forKey: .actions)
            ?? container.decodeIfPresent([String: PetActionOverridePayload].self, forKey: .overrides)
            ?? [:]
        let overrides = try payloads.keys.sorted().map { rawActionId in
            guard let actionId = ActionId(rawValue: rawActionId) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .actions,
                    in: container,
                    debugDescription: "Invalid action override id: \(rawActionId)"
                )
            }
            let payload = payloads[rawActionId]!
            return PetActionOverride(
                actionId: actionId,
                displayName: payload.displayName,
                tags: payload.tags,
                role: payload.role,
                frameDurationsMs: payload.frameDurationsMs
            )
        }

        self.init(
            overrideSchemaVersion: overrideSchemaVersion,
            petId: petId,
            overrides: overrides
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overrideSchemaVersion, forKey: .overrideSchemaVersion)
        try container.encode(petId, forKey: .petId)

        let payloads = Dictionary(
            uniqueKeysWithValues: overridesByActionId.values.map { override in
                (
                    override.actionId.rawValue,
                    PetActionOverridePayload(
                        displayName: override.displayName,
                        tags: override.tags,
                        role: override.role,
                        frameDurationsMs: override.frameDurationsMs
                    )
                )
            }
        )
        try container.encode(payloads, forKey: .actions)
    }
}

private struct PetActionOverridePayload: Codable, Equatable {
    let displayName: String?
    let tags: [ActionTag]?
    let role: ActionRole?
    let frameDurationsMs: [Int]?
}
