public struct PetActionCatalogBuildInput: Equatable {
    public let petId: String
    public let schemaVersion: Int
    public let legacyAnimations: [PetState: ManifestAnimationClip]?
    public let actions: [Action]
    public let spritesheet: SpriteSheetLayout?

    public init(
        petId: String,
        schemaVersion: Int,
        legacyAnimations: [PetState: ManifestAnimationClip]?,
        actions: [Action],
        spritesheet: SpriteSheetLayout?
    ) {
        self.petId = petId
        self.schemaVersion = schemaVersion
        self.legacyAnimations = legacyAnimations
        self.actions = actions
        self.spritesheet = spritesheet
    }
}
