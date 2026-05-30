public struct PetPackageManifest: Codable, Equatable {
    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let description: String
    public let asset: String
    public let preview: String?
    public let assetKind: PetAssetKind
    public let frameSize: CGSizeCodable
    public let spritesheet: SpriteSheetLayout?
    public let defaultScale: Double
    public let actions: [Action]
    public let legacyAnimations: [PetState: ManifestAnimationClip]?
    public let motionProfile: MotionProfile?
    public let bubbleProfile: BubbleProfile?

    public var animations: [PetState: ManifestAnimationClip] {
        if let legacyAnimations {
            return legacyAnimations
        }
        var derived: [PetState: ManifestAnimationClip] = [:]
        for action in actions {
            guard let role = action.role else { continue }
            let state = role.legacyState
            guard derived[state] == nil else { continue }
            let nextState: PetState? = action.nextActionId.flatMap { nextId in
                actions.first(where: { $0.id == nextId })?.role?.legacyState
            }
            derived[state] = ManifestAnimationClip(
                frames: action.frames,
                frameDurationMs: action.frameDurationMs,
                loop: action.loop,
                nextState: nextState
            )
        }
        return derived
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case displayName
        case description
        case asset
        case preview
        case assetKind
        case frameSize
        case spritesheet
        case defaultScale
        case actions
        case animations
        case motionProfile
        case bubbleProfile
    }

    public init(
        schemaVersion: Int,
        id: String,
        displayName: String,
        description: String,
        asset: String,
        preview: String?,
        frameSize: CGSizeCodable,
        spritesheet: SpriteSheetLayout?,
        defaultScale: Double,
        animations: [PetState: ManifestAnimationClip],
        assetKind: PetAssetKind = .spriteSheet,
        motionProfile: MotionProfile? = nil,
        bubbleProfile: BubbleProfile? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.description = description
        self.asset = asset
        self.preview = preview
        self.assetKind = assetKind
        self.frameSize = frameSize
        self.spritesheet = spritesheet
        self.defaultScale = defaultScale
        self.actions = []
        self.legacyAnimations = animations
        self.motionProfile = motionProfile
        self.bubbleProfile = bubbleProfile
    }

    public init(
        schemaVersion: Int,
        id: String,
        displayName: String,
        description: String,
        asset: String,
        preview: String?,
        frameSize: CGSizeCodable,
        spritesheet: SpriteSheetLayout?,
        defaultScale: Double,
        actions: [Action],
        assetKind: PetAssetKind = .spriteSheet,
        motionProfile: MotionProfile? = nil,
        bubbleProfile: BubbleProfile? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.description = description
        self.asset = asset
        self.preview = preview
        self.assetKind = assetKind
        self.frameSize = frameSize
        self.spritesheet = spritesheet
        self.defaultScale = defaultScale
        self.actions = actions
        self.legacyAnimations = nil
        self.motionProfile = motionProfile
        self.bubbleProfile = bubbleProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.schemaVersion = schemaVersion
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.description = try container.decode(String.self, forKey: .description)
        self.asset = try container.decode(String.self, forKey: .asset)
        self.preview = try container.decodeIfPresent(String.self, forKey: .preview)
        self.assetKind = try container.decodeIfPresent(PetAssetKind.self, forKey: .assetKind) ?? .spriteSheet
        self.frameSize = try container.decode(CGSizeCodable.self, forKey: .frameSize)
        self.spritesheet = try container.decodeIfPresent(SpriteSheetLayout.self, forKey: .spritesheet)
        self.defaultScale = try container.decode(Double.self, forKey: .defaultScale)
        self.motionProfile = try container.decodeIfPresent(MotionProfile.self, forKey: .motionProfile)
        self.bubbleProfile = try container.decodeIfPresent(BubbleProfile.self, forKey: .bubbleProfile)

        switch schemaVersion {
        case 1:
            self.legacyAnimations = try Self.decodeLegacyAnimations(from: container)
            self.actions = []
        case 2:
            if let decodedActions = try container.decodeIfPresent([Action].self, forKey: .actions) {
                self.actions = decodedActions
                self.legacyAnimations = nil
            } else if container.contains(.animations) {
                self.legacyAnimations = try Self.decodeLegacyAnimations(from: container)
                self.actions = []
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.actions,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Schema v2 manifest must include either `actions` or `animations`."
                    )
                )
            }
        default:
            throw ActionCatalogError.unsupportedSchemaVersion(schemaVersion)
        }
    }

    private static func decodeLegacyAnimations(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [PetState: ManifestAnimationClip] {
        let rawAnimations = try container.decode([String: ManifestAnimationClip].self, forKey: .animations)
        return try Dictionary(uniqueKeysWithValues: rawAnimations.map { key, clip in
            guard let state = PetState(rawValue: key) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .animations,
                    in: container,
                    debugDescription: "Unknown pet animation state: \(key)"
                )
            }
            return (state, clip)
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(2, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(asset, forKey: .asset)
        try container.encodeIfPresent(preview, forKey: .preview)
        try container.encode(assetKind, forKey: .assetKind)
        try container.encode(frameSize, forKey: .frameSize)
        try container.encodeIfPresent(spritesheet, forKey: .spritesheet)
        try container.encode(defaultScale, forKey: .defaultScale)
        try container.encodeIfPresent(motionProfile, forKey: .motionProfile)
        try container.encodeIfPresent(bubbleProfile, forKey: .bubbleProfile)

        let actionsToEncode: [Action]
        if !actions.isEmpty {
            actionsToEncode = actions
        } else if let legacyAnimations {
            actionsToEncode = LegacyAnimationsAdapter().actions(from: legacyAnimations)
        } else {
            actionsToEncode = []
        }
        try container.encode(actionsToEncode, forKey: .actions)
    }

    public func petDefinition(overrides: PetActionOverrideSet? = nil) throws -> PetDefinition {
        let buildInput: PetActionCatalogBuildInput
        if !actions.isEmpty {
            buildInput = PetActionCatalogBuildInput(
                petId: id,
                schemaVersion: 2,
                legacyAnimations: nil,
                actions: actions,
                spritesheet: spritesheet
            )
        } else if let legacyAnimations {
            buildInput = PetActionCatalogBuildInput(
                petId: id,
                schemaVersion: 1,
                legacyAnimations: legacyAnimations,
                actions: [],
                spritesheet: spritesheet
            )
        } else {
            buildInput = PetActionCatalogBuildInput(
                petId: id,
                schemaVersion: schemaVersion,
                legacyAnimations: nil,
                actions: [],
                spritesheet: spritesheet
            )
        }

        let catalog = try DefaultPetActionCatalogBuilder().build(input: buildInput, overrides: overrides)

        return try PetDefinition(
            id: id,
            displayName: displayName,
            description: description,
            assetName: asset,
            previewAssetName: preview,
            frameSize: frameSize,
            spritesheet: spritesheet,
            defaultScale: defaultScale,
            catalog: catalog,
            assetKind: assetKind,
            motionProfile: motionProfile,
            bubbleProfile: bubbleProfile
        ).validated()
    }
}

public struct ManifestAnimationClip: Codable, Equatable {
    public let frames: [SpriteFrame]
    public let frameDurationMs: Int
    public let loop: Bool
    public let nextState: PetState?

    public init(
        frames: [SpriteFrame],
        frameDurationMs: Int,
        loop: Bool,
        nextState: PetState? = nil
    ) {
        self.frames = frames
        self.frameDurationMs = frameDurationMs
        self.loop = loop
        self.nextState = nextState
    }
}
