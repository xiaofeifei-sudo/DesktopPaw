import Foundation
import DesktopPet

@MainActor
func runPetDefinitionCatalogTests() {
    let tests = PetDefinitionCatalogTests()
    tests.testCatalogStoredAndAnimationsDerived()
    tests.testAnimationFallbackForMissingWalking()
    tests.testAnimationFallbackForMissingJumping()
    tests.testClipForActionId()
    tests.testValidatedAcceptsRolelessCatalogs()
    tests.testJumpingFallsBackToIdleWhenHappyAlsoMissing()
    tests.testCodableRoundTripsLegacyAnimationsJSON()
}

private struct PetDefinitionCatalogTests {
    func testCatalogStoredAndAnimationsDerived() {
        let definition = makeDefinition(states: PetState.allCases)
        expect(definition.catalog.actions.count == PetState.allCases.count, "catalog should expose one action per legacy state")

        let animations = definition.animations
        expect(animations.count == PetState.allCases.count, "derived animations should cover every state present in catalog")

        for state in PetState.allCases {
            guard let clip = animations[state] else {
                fail("derived animations should include \(state)")
            }
            expect(clip.state == state, "derived clip should report its own state for \(state)")
            expect(!clip.frames.isEmpty, "derived clip should preserve frames for \(state)")
        }
    }

    func testAnimationFallbackForMissingWalking() {
        let states = PetState.allCases.filter { $0 != .walking }
        let definition = makeDefinition(states: states)

        guard let clip = definition.animation(for: .walking) else {
            fail("missing walking should resolve to fallback clip")
        }
        expect(clip.state == .idle, "missing walking should fall back to idle clip")
        expect(definition.animations[.walking] == nil, "derived animations should omit missing walking entry")
    }

    func testAnimationFallbackForMissingJumping() {
        let states = PetState.allCases.filter { $0 != .jumping }
        let definition = makeDefinition(states: states)

        guard let clip = definition.animation(for: .jumping) else {
            fail("missing jumping should resolve to fallback clip")
        }
        expect(clip.state == .happy, "missing jumping should fall back through happy first")
    }

    func testJumpingFallsBackToIdleWhenHappyAlsoMissing() {
        let states = PetState.allCases.filter { $0 != .jumping && $0 != .happy }
        let definition = makeDefinition(states: states)

        guard let clip = definition.animation(for: .jumping) else {
            fail("jumping should still fall back when happy is also missing")
        }
        expect(clip.state == .idle, "missing jumping with missing happy should fall back to idle")
    }

    func testClipForActionId() {
        let extraId = ActionId(rawValue: "extra_1")!
        let extraAction = Action(
            id: extraId,
            displayName: "Extra",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 4, row: 2)],
            frameDurationMs: 240,
            loop: false,
            nextActionId: nil
        )

        let baseActions = makeBaseActions(states: PetState.allCases)
        let catalog = PetActionCatalog(petId: "pet-with-extra", actions: baseActions + [extraAction], warnings: [])
        let definition = makeDefinition(catalog: catalog)

        guard let clip = definition.clip(for: extraId) else {
            fail("clip(for:) should resolve extra action by id")
        }
        expect(clip.frames == extraAction.frames, "clip(for:) frames should match underlying action")
        expect(clip.frameDurationMs == 240, "clip(for:) duration should match underlying action")
        expect(clip.loop == false, "clip(for:) loop flag should match underlying action")
    }

    func testValidatedAcceptsRolelessCatalogs() {
        let rolelessAction = Action(
            id: ActionId(rawValue: "action_1")!,
            displayName: "Action 1",
            role: nil,
            tags: [],
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 160,
            loop: true,
            nextActionId: nil
        )
        let minimalDefinition = makeDefinition(catalog: PetActionCatalog(
            petId: "roleless-pet",
            actions: [rolelessAction],
            warnings: []
        ))
        do {
            _ = try minimalDefinition.validated()
        } catch {
            fail("validated() should succeed for a role-less action catalog: \(error)")
        }

        let missingLegacyRoles = makeDefinition(states: [.walking, .happy])
        do {
            _ = try missingLegacyRoles.validated()
        } catch {
            fail("validated() should not require fixed idle or dragging roles: \(error)")
        }

        let emptyCatalog = makeDefinition(catalog: PetActionCatalog(
            petId: "empty-pet",
            actions: [],
            warnings: []
        ))
        do {
            _ = try emptyCatalog.validated()
            fail("validated() should reject catalogs with no actions")
        } catch PetAssetError.invalidPackageStructure {
        } catch {
            fail("validated() should report invalid package structure for an empty action catalog, got \(error)")
        }
    }

    func testCodableRoundTripsLegacyAnimationsJSON() {
        let definition = makeDefinition(states: PetState.allCases)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        do {
            let data = try encoder.encode(definition)
            let decoded = try decoder.decode(PetDefinition.self, from: data)
            expect(decoded.animations.count == PetState.allCases.count, "decoded definition should keep all legacy animation entries")
            expect(decoded.catalog.actionsByRole[.idle]?.first != nil, "decoded definition catalog should rebuild idle role")
            expect(decoded.catalog.actionsByRole[.dragging]?.first != nil, "decoded definition catalog should rebuild dragging role")
        } catch {
            fail("PetDefinition Codable should round-trip via legacy animations JSON: \(error)")
        }
    }

    private func makeDefinition(states: [PetState]) -> PetDefinition {
        let actions = makeBaseActions(states: states)
        let catalog = PetActionCatalog(petId: "catalog-pet", actions: actions, warnings: [])
        return makeDefinition(catalog: catalog)
    }

    private func makeBaseActions(states: [PetState]) -> [Action] {
        states.enumerated().map { index, state in
            let role = ActionRole(legacyState: state)
            let id = ActionId(rawValue: "\(state.rawValue)_default")!
            return Action(
                id: id,
                displayName: state.rawValue,
                role: role,
                tags: [],
                frames: [SpriteFrame(column: index, row: 0)],
                frameDurationMs: 160,
                loop: state == .idle || state == .walking || state == .sleeping || state == .dragging,
                nextActionId: nil
            )
        }
    }

    private func makeDefinition(catalog: PetActionCatalog) -> PetDefinition {
        PetDefinition(
            id: "catalog-pet",
            displayName: "Catalog Pet",
            description: "test fixture",
            assetName: "catalog-pet",
            previewAssetName: nil,
            frameSize: CGSizeCodable(width: 128, height: 128),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 4),
            defaultScale: 1.0,
            catalog: catalog,
            assetKind: .spriteSheet
        )
    }
}
