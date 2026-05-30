import Foundation

public final class BuiltInPetDefinitionProvider {
    public init() {}

    public func loadBuiltInPet() throws -> PetDefinition {
        try PetDefinition(
            id: "starter-pet",
            displayName: "Starter Pet",
            description: "A small built-in desktop companion.",
            assetName: "starter-pet-spritesheet",
            previewAssetName: "starter-pet-preview",
            frameSize: CGSizeCodable(width: 128, height: 128),
            spritesheet: SpriteSheetLayout(columns: 7, rows: 1),
            defaultScale: 1.0,
            animations: [
                .idle: AnimationClip(
                    state: .idle,
                    frames: [SpriteFrame(column: 0, row: 0)],
                    frameDurationMs: 160,
                    loop: true
                ),
                .walking: AnimationClip(
                    state: .walking,
                    frames: [SpriteFrame(column: 1, row: 0)],
                    frameDurationMs: 140,
                    loop: true
                ),
                .sleeping: AnimationClip(
                    state: .sleeping,
                    frames: [SpriteFrame(column: 2, row: 0)],
                    frameDurationMs: 300,
                    loop: true
                ),
                .happy: AnimationClip(
                    state: .happy,
                    frames: [SpriteFrame(column: 3, row: 0)],
                    frameDurationMs: 120,
                    loop: false,
                    nextState: .idle
                ),
                .eating: AnimationClip(
                    state: .eating,
                    frames: [SpriteFrame(column: 4, row: 0)],
                    frameDurationMs: 120,
                    loop: false,
                    nextState: .idle
                ),
                .jumping: AnimationClip(
                    state: .jumping,
                    frames: [SpriteFrame(column: 5, row: 0)],
                    frameDurationMs: 110,
                    loop: false,
                    nextState: .idle
                ),
                .dragging: AnimationClip(
                    state: .dragging,
                    frames: [SpriteFrame(column: 6, row: 0)],
                    frameDurationMs: 160,
                    loop: true
                )
            ]
        ).validated()
    }

    public func bundledResourceExists(named name: String, extension fileExtension: String = "png") -> Bool {
        DesktopPetResources.url(named: name, extension: fileExtension) != nil
    }

    public func bundledResourceURL(named name: String, extension fileExtension: String = "png") -> URL? {
        DesktopPetResources.url(named: name, extension: fileExtension)
    }
}
