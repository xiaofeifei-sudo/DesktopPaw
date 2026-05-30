import Foundation

public struct PetDefinition: Codable, Equatable {
    public static let placeholderAssetName = "placeholder-pet"

    public let id: String
    public let displayName: String
    public let description: String
    public let assetName: String
    public let previewAssetName: String?
    public let assetKind: PetAssetKind
    public let frameSize: CGSizeCodable
    public let spritesheet: SpriteSheetLayout?
    public let defaultScale: Double
    public let catalog: PetActionCatalog
    public let motionProfile: MotionProfile?
    public let bubbleProfile: BubbleProfile?
    public let renderAssetLibrary: PetRenderAssetLibrary?

    public var animations: [PetState: AnimationClip] {
        var derived: [PetState: AnimationClip] = [:]
        for state in PetState.allCases {
            let role = ActionRole(legacyState: state)
            guard let action = catalog.actionsByRole[role]?.first else { continue }
            derived[state] = Self.makeClip(from: action, state: state, in: catalog)
        }
        return derived
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        assetName: String,
        previewAssetName: String?,
        frameSize: CGSizeCodable,
        spritesheet: SpriteSheetLayout? = nil,
        defaultScale: Double,
        catalog: PetActionCatalog,
        assetKind: PetAssetKind = .spriteSheet,
        motionProfile: MotionProfile? = nil,
        bubbleProfile: BubbleProfile? = nil,
        renderAssetLibrary: PetRenderAssetLibrary? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.assetName = assetName
        self.previewAssetName = previewAssetName
        self.assetKind = assetKind
        self.frameSize = frameSize
        self.spritesheet = spritesheet
        self.defaultScale = defaultScale
        self.catalog = catalog
        self.motionProfile = motionProfile
        self.bubbleProfile = bubbleProfile
        self.renderAssetLibrary = renderAssetLibrary
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        assetName: String,
        previewAssetName: String?,
        frameSize: CGSizeCodable,
        spritesheet: SpriteSheetLayout? = nil,
        defaultScale: Double,
        animations: [PetState: AnimationClip],
        assetKind: PetAssetKind = .spriteSheet,
        motionProfile: MotionProfile? = nil,
        bubbleProfile: BubbleProfile? = nil
    ) {
        let catalog = Self.makeCatalog(petId: id, animations: animations)
        self.init(
            id: id,
            displayName: displayName,
            description: description,
            assetName: assetName,
            previewAssetName: previewAssetName,
            frameSize: frameSize,
            spritesheet: spritesheet,
            defaultScale: defaultScale,
            catalog: catalog,
            assetKind: assetKind,
            motionProfile: motionProfile,
            bubbleProfile: bubbleProfile
        )
    }

    public func validated() throws -> PetDefinition {
        switch assetKind {
        case .spriteSheet:
            try validateSpriteSheet()
        case .singleImage:
            try validateSingleImage()
        }
        return self
    }

    private func validateSpriteSheet() throws {
        guard let spritesheet else {
            throw PetAssetError.invalidSpriteSheetLayout
        }

        guard spritesheet.columns > 0, spritesheet.rows > 0 else {
            throw PetAssetError.invalidSpriteSheetLayout
        }

        try validateActionsPresent()
        try validateActionFrames(spritesheet: spritesheet)
    }

    private func validateSingleImage() throws {
        guard frameSize.width > 0, frameSize.height > 0 else {
            throw PetAssetError.invalidSpriteSheetLayout
        }

        try validateActionsPresent()
        try validateActionFrames(spritesheet: nil)
    }

    private func validateActionsPresent() throws {
        guard !catalog.actions.isEmpty else {
            throw PetAssetError.invalidPackageStructure("Pet package must include at least one action.")
        }
    }

    private func validateActionFrames(spritesheet: SpriteSheetLayout?) throws {
        for action in catalog.actions {
            let state = action.role?.legacyState ?? .idle
            guard !action.frames.isEmpty else {
                throw PetAssetError.emptyAnimation(state)
            }

            if let spritesheet {
                for frame in action.frames {
                    guard frame.column >= 0,
                          frame.column < spritesheet.columns,
                          frame.row >= 0,
                          frame.row < spritesheet.rows
                    else {
                        throw PetAssetError.frameOutOfBounds(state: state, frame: frame)
                    }
                }
            }
        }
    }

    public func animation(for state: PetState) -> AnimationClip? {
        let role = ActionRole(legacyState: state)
        let resolver = DefaultActionFallbackResolver()
        guard let action = resolver.resolve(role: role, in: catalog) ?? catalog.defaultAction else {
            return nil
        }
        let clipState = action.role?.legacyState ?? .idle
        return Self.makeClip(from: action, state: clipState, in: catalog)
    }

    public func clip(for actionId: ActionId) -> AnimationClip? {
        guard let action = catalog.resolve(actionId: actionId) else {
            return nil
        }
        let clipState = action.role?.legacyState ?? .idle
        return Self.makeClip(from: action, state: clipState, in: catalog)
    }

    public func renderAssetName(resourceExists: (String) -> Bool) -> String {
        if resourceExists(assetName) {
            return assetName
        }

        if let previewAssetName, resourceExists(previewAssetName) {
            return previewAssetName
        }

        return Self.placeholderAssetName
    }

    public func resolvedMotionProfile() -> MotionProfile {
        motionProfile ?? MotionProfileDefaults.singleImageDefault()
    }

    public func resolvedBubbleProfile() -> BubbleProfile {
        bubbleProfile ?? BubbleProfileDefaults.defaultProfile()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case description
        case assetName
        case previewAssetName
        case assetKind
        case frameSize
        case spritesheet
        case defaultScale
        case animations
        case motionProfile
        case bubbleProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let description = try container.decode(String.self, forKey: .description)
        let assetName = try container.decode(String.self, forKey: .assetName)
        let previewAssetName = try container.decodeIfPresent(String.self, forKey: .previewAssetName)
        let assetKind = try container.decodeIfPresent(PetAssetKind.self, forKey: .assetKind) ?? .spriteSheet
        let frameSize = try container.decode(CGSizeCodable.self, forKey: .frameSize)
        let spritesheet = try container.decodeIfPresent(SpriteSheetLayout.self, forKey: .spritesheet)
        let defaultScale = try container.decode(Double.self, forKey: .defaultScale)
        let animations = try container.decode([PetState: AnimationClip].self, forKey: .animations)
        let motionProfile = try container.decodeIfPresent(MotionProfile.self, forKey: .motionProfile)
        let bubbleProfile = try container.decodeIfPresent(BubbleProfile.self, forKey: .bubbleProfile)

        self.init(
            id: id,
            displayName: displayName,
            description: description,
            assetName: assetName,
            previewAssetName: previewAssetName,
            frameSize: frameSize,
            spritesheet: spritesheet,
            defaultScale: defaultScale,
            animations: animations,
            assetKind: assetKind,
            motionProfile: motionProfile,
            bubbleProfile: bubbleProfile
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(assetName, forKey: .assetName)
        try container.encodeIfPresent(previewAssetName, forKey: .previewAssetName)
        try container.encode(assetKind, forKey: .assetKind)
        try container.encode(frameSize, forKey: .frameSize)
        try container.encodeIfPresent(spritesheet, forKey: .spritesheet)
        try container.encode(defaultScale, forKey: .defaultScale)
        try container.encode(animations, forKey: .animations)
        try container.encodeIfPresent(motionProfile, forKey: .motionProfile)
        try container.encodeIfPresent(bubbleProfile, forKey: .bubbleProfile)
    }

    private static func makeCatalog(petId: String, animations: [PetState: AnimationClip]) -> PetActionCatalog {
        let actions: [Action] = animations.map { state, clip in
            let role = ActionRole(legacyState: state)
            let id = ActionId(rawValue: "\(state.rawValue)_default")!
            let nextActionId = clip.nextState.map { ActionId(rawValue: "\($0.rawValue)_default")! }
            return Action(
                id: id,
                displayName: state.rawValue.prefix(1).uppercased() + state.rawValue.dropFirst(),
                role: role,
                tags: [],
                frames: clip.frames,
                frameDurationMs: clip.frameDurationMs,
                loop: clip.loop,
                nextActionId: nextActionId
            )
        }
        return PetActionCatalog(petId: petId, actions: actions, warnings: [])
    }

    private static func makeClip(from action: Action, state: PetState, in catalog: PetActionCatalog) -> AnimationClip {
        let nextState: PetState? = action.nextActionId.flatMap { nextId in
            catalog.actionsById[nextId]?.role.map { $0.legacyState }
        }
        let normalizedFrames = action.frames.map { frame -> SpriteFrame in
            if frame.assetId == nil, let actionAssetId = action.assetId {
                return SpriteFrame(
                    assetId: actionAssetId,
                    column: frame.column,
                    row: frame.row,
                    durationMs: frame.durationMs
                )
            }
            return frame
        }
        return AnimationClip(
            state: state,
            frames: normalizedFrames,
            frameDurationMs: action.frameDurationMs,
            loop: action.loop,
            nextState: nextState
        )
    }
}
