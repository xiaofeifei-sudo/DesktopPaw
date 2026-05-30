import Foundation
import DesktopPet

@MainActor
func runPetDefinitionCompatibilityTests() {
    let tests = PetDefinitionCompatibilityTests()
    tests.builtInPetLoadsAsSpriteSheet()
    tests.singleImageManifestDecodes()
    tests.legacyV1ManifestDefaultsToSpriteSheet()
    tests.singleImageDefinitionFallsBackToDefaultProfiles()
    tests.singleImageManifestSurvivesWithoutSpritesheet()
    tests.singleImageDefinitionDoesNotRequireSpritesheetBounds()
    tests.builtInPetDefaultBubbleCatalog()
    tests.singleImagePetDefaultBubbleCatalog()
    tests.petdexDefinitionDefaultBubbleProfile()
    tests.builtInPetBubbleEngineWithDefaultCatalog()
    tests.customSingleImageBubbleEngineWithDefaultCatalog()
    tests.bubbleEngineLegacyStateTriggersStillWork()
}

@MainActor
private struct PetDefinitionCompatibilityTests {
    func builtInPetLoadsAsSpriteSheet() {
        let provider = BuiltInPetDefinitionProvider()
        do {
            let definition = try provider.loadBuiltInPet()
            expect(definition.assetKind == .spriteSheet, "built-in pet should default to spriteSheet kind")
            expect(definition.spritesheet != nil, "built-in pet should retain spritesheet layout")
            expect(definition.motionProfile == nil, "built-in pet should not require motion profile")
            expect(definition.bubbleProfile == nil, "built-in pet should not require bubble profile")
        } catch {
            fail("built-in pet should load: \(error)")
        }
    }

    func singleImageManifestDecodes() {
        let json = singleImageManifestJSON
        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: Data(json.utf8))
        } catch {
            fail("single image manifest should decode: \(error)")
        }

        expect(manifest.schemaVersion == 2, "schema version should be v2")
        expect(manifest.assetKind == .singleImage, "asset kind should decode as singleImage")
        expect(manifest.spritesheet == nil, "single image manifest should allow nil spritesheet")
        expect(manifest.motionProfile != nil, "single image manifest should decode motion profile")
        expect(manifest.bubbleProfile != nil, "single image manifest should decode bubble profile")

        let definition: PetDefinition
        do {
            definition = try manifest.petDefinition()
        } catch {
            fail("single image manifest should produce a valid pet definition: \(error)")
        }

        expect(definition.assetKind == .singleImage, "pet definition should preserve singleImage kind")
        expect(definition.animations.count == PetState.allCases.count, "single image definition should have all seven states")
    }

    func legacyV1ManifestDefaultsToSpriteSheet() {
        let json = """
        {
          "schemaVersion": 1,
          "id": "legacy-pet",
          "displayName": "Legacy Pet",
          "description": "Legacy v1 pet.",
          "asset": "spritesheet.png",
          "preview": "preview.png",
          "frameSize": { "width": 128, "height": 128 },
          "spritesheet": { "columns": 1, "rows": 1 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 110, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 160, "loop": true }
          }
        }
        """

        let manifest: PetPackageManifest
        do {
            manifest = try JSONDecoder().decode(PetPackageManifest.self, from: Data(json.utf8))
        } catch {
            fail("legacy v1 manifest should still decode: \(error)")
        }

        expect(manifest.assetKind == .spriteSheet, "legacy manifest without assetKind should default to spriteSheet")
        expect(manifest.motionProfile == nil, "legacy manifest should not require motion profile")
        expect(manifest.bubbleProfile == nil, "legacy manifest should not require bubble profile")

        do {
            let definition = try manifest.petDefinition()
            expect(definition.assetKind == .spriteSheet, "definition derived from legacy manifest should be spriteSheet")
        } catch {
            fail("legacy v1 manifest should produce a valid pet definition: \(error)")
        }
    }

    func singleImageDefinitionFallsBackToDefaultProfiles() {
        let definition = makeSingleImageDefinition(motionProfile: nil, bubbleProfile: nil)

        let resolvedMotion = definition.resolvedMotionProfile()
        expect(resolvedMotion.stateMotions.count == PetState.allCases.count, "default motion profile should cover all seven states")

        let resolvedBubble = definition.resolvedBubbleProfile()
        expect(resolvedBubble.minimumIntervalSeconds > 0, "default bubble profile should have positive minimum interval")
        expect(!resolvedBubble.phrases.isEmpty, "default bubble profile should provide phrases")
    }

    func singleImageManifestSurvivesWithoutSpritesheet() {
        let definition = makeSingleImageDefinition()
        do {
            _ = try definition.validated()
        } catch {
            fail("single image definition without spritesheet should validate: \(error)")
        }
    }

    func singleImageDefinitionDoesNotRequireSpritesheetBounds() {
        let definition = PetDefinition(
            id: "single",
            displayName: "Single",
            description: "single image pet",
            assetName: "image.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 256, height: 256),
            spritesheet: nil,
            defaultScale: 1.0,
            animations: Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
                (
                    state,
                    AnimationClip(
                        state: state,
                        frames: [SpriteFrame(column: 5, row: 5)],
                        frameDurationMs: 200,
                        loop: true
                    )
                )
            }),
            assetKind: .singleImage
        )

        do {
            _ = try definition.validated()
        } catch {
            fail("single image definition should ignore frame bounds checks: \(error)")
        }
    }

    func builtInPetDefaultBubbleCatalog() {
        let builtInDefinition = makeBuiltInDefinition()
        let profile = builtInDefinition.resolvedBubbleProfile()
        let catalog = BubblePhraseCatalogBuilder().build(from: profile)

        for trigger in [BubbleTrigger.clicked, .pet, .feed, .hungry, .tired, .idle] {
            let phrases = catalog.phrases(for: trigger)
            expect(!phrases.isEmpty, "built-in pet default catalog must cover \(trigger.rawValue)")
        }

        for trigger in [BubbleTrigger.dailyGreeting, .longAbsenceReturn, .actionLine] {
            let phrases = catalog.phrases(for: trigger)
            expect(!phrases.isEmpty, "built-in pet default catalog must cover companion trigger \(trigger.rawValue)")
        }
    }

    func singleImagePetDefaultBubbleCatalog() {
        let definition = makeSingleImageDefinition()
        let profile = definition.resolvedBubbleProfile()
        let catalog = BubblePhraseCatalogBuilder().build(from: profile)

        expect(!catalog.isEmpty, "single image pet should get non-empty default catalog")
        expect(catalog.phrases(for: .clicked).count >= 3, "single image pet default catalog should have multiple clicked phrases")
    }

    func petdexDefinitionDefaultBubbleProfile() {
        let definition = PetDefinition(
            id: "petdex-cat",
            displayName: "Petdex Cat",
            description: "imported from Petdex",
            assetName: "spritesheet.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 128, height: 128),
            spritesheet: SpriteSheetLayout(columns: 8, rows: 9),
            defaultScale: 1.0,
            animations: Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
                (
                    state,
                    AnimationClip(
                        state: state,
                        frames: [SpriteFrame(column: 0, row: 0)],
                        frameDurationMs: 160,
                        loop: true
                    )
                )
            }),
            assetKind: .spriteSheet,
            bubbleProfile: nil
        )

        let profile = definition.resolvedBubbleProfile()
        expect(profile.minimumIntervalSeconds > 0, "Petdex definition should get valid default bubble profile")

        let catalog = BubblePhraseCatalogBuilder().build(from: profile)
        expect(!catalog.isEmpty, "Petdex definition should get non-empty default catalog")
        expect(catalog.phrases(for: .actionLine).count >= 1, "Petdex definition default catalog should include actionLine phrases")
    }

    @MainActor
    func builtInPetBubbleEngineWithDefaultCatalog() {
        let builtInDefinition = makeBuiltInDefinition()
        let profile = builtInDefinition.resolvedBubbleProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = PetRuntimeState.defaultState(at: now)

        let bubble = engine.handle(event: .clicked, state: state, at: now)
        expect(bubble != nil, "built-in pet should produce bubble via default catalog")
        expect(bubble?.priority == .interaction, "built-in pet click bubble should be interaction priority")
    }

    @MainActor
    func customSingleImageBubbleEngineWithDefaultCatalog() {
        let definition = makeSingleImageDefinition()
        let profile = definition.resolvedBubbleProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = PetRuntimeState.defaultState(at: now)
        state.hunger = 0.8
        state.currentState = .idle

        let bubble = engine.tick(state: state, at: now.addingTimeInterval(10))
        expect(bubble != nil, "custom single image pet should produce bubble via default catalog")
        expect(bubble?.priority == .state, "custom single image pet hungry bubble should be state priority")
    }

    @MainActor
    func bubbleEngineLegacyStateTriggersStillWork() {
        let profile = BubbleProfileDefaults.defaultProfile()
        let engine = BubbleEngine(
            profile: profile,
            phraseProvider: DefaultBubblePhraseProvider(profile: profile, selector: { $0.first })
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        var hungryState = PetRuntimeState.defaultState(at: now)
        hungryState.hunger = 0.8
        hungryState.currentState = .idle
        let hungry = engine.tick(state: hungryState, at: now.addingTimeInterval(10))
        expect(hungry?.priority == .state, "hungry trigger should still produce state bubble")

        var tiredState = PetRuntimeState.defaultState(at: now.addingTimeInterval(60))
        tiredState.energy = 0.2
        tiredState.hunger = 0.1
        tiredState.currentState = .idle
        let tired = engine.tick(state: tiredState, at: now.addingTimeInterval(70))
        expect(tired?.priority == .state, "tired trigger should still produce state bubble")
    }

    private func makeBuiltInDefinition() -> PetDefinition {
        let provider = BuiltInPetDefinitionProvider()
        return (try? provider.loadBuiltInPet()) ?? PetDefinition(
            id: "starter-pet",
            displayName: "Starter Pet",
            description: "fallback",
            assetName: "starter-pet-spritesheet",
            previewAssetName: nil,
            frameSize: CGSizeCodable(width: 128, height: 128),
            spritesheet: SpriteSheetLayout(columns: 7, rows: 1),
            defaultScale: 1.0,
            animations: Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
                (state, AnimationClip(state: state, frames: [SpriteFrame(column: 0, row: 0)], frameDurationMs: 160, loop: true))
            })
        )
    }

    private func makeSingleImageDefinition(
        motionProfile: MotionProfile? = nil,
        bubbleProfile: BubbleProfile? = nil
    ) -> PetDefinition {
        PetDefinition(
            id: "test-single",
            displayName: "Test Single",
            description: "single image fixture",
            assetName: "image.png",
            previewAssetName: "preview.png",
            frameSize: CGSizeCodable(width: 256, height: 256),
            spritesheet: nil,
            defaultScale: 1.0,
            animations: Dictionary(uniqueKeysWithValues: PetState.allCases.map { state in
                (
                    state,
                    AnimationClip(
                        state: state,
                        frames: [SpriteFrame(column: 0, row: 0)],
                        frameDurationMs: 200,
                        loop: state == .idle || state == .walking || state == .sleeping || state == .dragging
                    )
                )
            }),
            assetKind: .singleImage,
            motionProfile: motionProfile,
            bubbleProfile: bubbleProfile
        )
    }

    private var singleImageManifestJSON: String {
        """
        {
          "schemaVersion": 2,
          "id": "momo-7f3a",
          "displayName": "Momo",
          "description": "user single image",
          "asset": "image.png",
          "preview": "preview.png",
          "assetKind": "singleImage",
          "frameSize": { "width": 512, "height": 512 },
          "defaultScale": 1.0,
          "animations": {
            "idle": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "walking": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "sleeping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true },
            "happy": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "eating": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "jumping": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": false, "nextState": "idle" },
            "dragging": { "frames": [{ "column": 0, "row": 0 }], "frameDurationMs": 1000, "loop": true }
          },
          "motionProfile": {
            "stateMotions": {
              "idle": { "kind": "bob", "amplitude": 4, "durationMs": 1800, "loop": true },
              "walking": { "kind": "drift", "amplitude": 6, "durationMs": 1200, "loop": true },
              "sleeping": { "kind": "bob", "amplitude": 2, "durationMs": 2400, "loop": true },
              "happy": { "kind": "bounce", "amplitude": 12, "durationMs": 480, "loop": false },
              "eating": { "kind": "shake", "amplitude": 4, "durationMs": 360, "loop": false },
              "jumping": { "kind": "jump", "amplitude": 18, "durationMs": 420, "loop": false },
              "dragging": { "kind": "tilt", "amplitude": 6, "durationMs": 240, "loop": false }
            }
          },
          "bubbleProfile": {
            "minimumIntervalSeconds": 60,
            "displayDurationSeconds": 3,
            "phrases": {
              "clicked": ["你好"],
              "pet": ["开心"],
              "feed": ["好吃"],
              "hungry": ["有点饿"],
              "tired": ["困了"],
              "happy": ["开心"],
              "idle": ["陪你一会儿"],
              "walking": ["走走"],
              "sleeping": ["zzz"]
            }
          }
        }
        """
    }
}
