import AppKit
import Foundation
import DesktopPet

@MainActor
func runPetViewRenderingTests() {
    let tests = PetViewRenderingTests()
    tests.renderSizeAppliesScale()
    tests.renderSizeUsesDefinitionFrameSize()
    tests.viewModelPublishesUpdatedState()
    tests.viewModelUsesProvidedDefaultState()
    tests.animationClipPrefersCurrentActionId()
    tests.animationClipFallsBackToCurrentStateWhenActionIdIsUnknown()
}

@MainActor
private struct PetViewRenderingTests {
    func renderSizeAppliesScale() {
        let definition = makeDefinition(width: 64, height: 64)
        var state = PetRuntimeState.defaultState()
        state.scale = 2.0

        let size = PetView.renderSize(for: definition, state: state)

        expect(size.width == 128, "render width should equal frame width times scale")
        expect(size.height == 128, "render height should equal frame height times scale")
    }

    func renderSizeUsesDefinitionFrameSize() {
        let definition = makeDefinition(width: 96, height: 48)
        var state = PetRuntimeState.defaultState()
        state.scale = 1.0

        let size = PetView.renderSize(for: definition, state: state)

        expect(size.width == 96, "render width should match frame size when scale is 1")
        expect(size.height == 48, "render height should match frame size when scale is 1")
    }

    func viewModelPublishesUpdatedState() {
        let model = PetViewModel(runtimeState: .defaultState())
        var updated = PetRuntimeState.defaultState()
        updated.currentState = .happy
        updated.scale = 1.5

        model.update(updated)

        expect(model.runtimeState.currentState == .happy, "model should reflect updated state")
        expect(model.runtimeState.scale == 1.5, "model should reflect updated scale")
    }

    func viewModelUsesProvidedDefaultState() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let custom = PetRuntimeState(
            currentState: .eating,
            mood: 0.5,
            hunger: 0.5,
            energy: 0.5,
            lastInteractionAt: baseDate,
            isDragging: false,
            scale: 0.75
        )
        let model = PetViewModel(runtimeState: custom)

        expect(model.runtimeState.currentState == .eating, "model should adopt provided initial state")
        expect(model.runtimeState.scale == 0.75, "model should adopt provided scale")
    }

    func animationClipPrefersCurrentActionId() {
        let extraId = ActionId(rawValue: "extra_1")!
        let definition = makeDefinitionWithExtra(extraId: extraId)
        var state = PetRuntimeState.defaultState()
        state.currentState = .idle
        state.currentActionId = extraId

        let clip = PetView.animationClip(for: definition, state: state)

        expect(clip.frames == [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)], "PetView should render the selected extra action while runtime state remains idle")
        expect(clip.loop == false, "selected extra clip should preserve one-shot playback")
    }

    func animationClipFallsBackToCurrentStateWhenActionIdIsUnknown() {
        let definition = makeDefinitionWithExtra(extraId: ActionId(rawValue: "extra_1")!)
        var state = PetRuntimeState.defaultState()
        state.currentState = .idle
        state.currentActionId = ActionId(rawValue: "missing_action")!

        let clip = PetView.animationClip(for: definition, state: state)

        expect(clip.frames == [SpriteFrame(column: 0, row: 0)], "unknown currentActionId should fall back to currentState animation")
        expect(clip.loop, "fallback idle clip should preserve looping playback")
    }
}

@MainActor
private func makeDefinition(width: Double, height: Double) -> PetDefinition {
    var animations: [PetState: AnimationClip] = [:]
    for state in PetState.allCases {
        animations[state] = AnimationClip(
            state: state,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 1_000,
            loop: true
        )
    }

    return PetDefinition(
        id: "render-host-pet",
        displayName: "Render Host",
        description: "render host test",
        assetName: "image.png",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: width, height: height),
        spritesheet: nil,
        defaultScale: 1.0,
        animations: animations,
        assetKind: .singleImage
    )
}

@MainActor
private func makeDefinitionWithExtra(extraId: ActionId) -> PetDefinition {
    let actions = PetState.allCases.map { state -> Action in
        let role = ActionRole(legacyState: state)
        return Action(
            id: ActionId(rawValue: "\(role.rawValue)_default")!,
            displayName: role.rawValue,
            role: role,
            tags: [],
            frames: [SpriteFrame(column: 0, row: state == .idle ? 0 : 1)],
            frameDurationMs: 160,
            loop: true
        )
    } + [
        Action(
            id: extraId,
            displayName: "Extra",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 7), SpriteFrame(column: 1, row: 7)],
            frameDurationMs: 120,
            loop: false,
            nextActionId: ActionId.idle
        )
    ]

    return PetDefinition(
        id: "render-extra-pet",
        displayName: "Render Extra",
        description: "render extra test",
        assetName: "image.png",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 64, height: 64),
        spritesheet: SpriteSheetLayout(columns: 2, rows: 8),
        defaultScale: 1.0,
        catalog: PetActionCatalog(petId: "render-extra-pet", actions: actions, warnings: []),
        assetKind: .spriteSheet
    )
}
