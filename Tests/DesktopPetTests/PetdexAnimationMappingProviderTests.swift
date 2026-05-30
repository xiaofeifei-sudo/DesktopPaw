import Foundation
import DesktopPet

func runPetdexAnimationMappingProviderTests() {
    let tests = PetdexAnimationMappingProviderTests()
    tests.recognizesEightByNineConventionAndDerivesFrameSize()
    tests.generatesAllMVPStateClips()
    tests.framesStayInsideSpritesheetBounds()
    tests.nonLoopingStatesReturnToIdle()
    tests.myCatV3LargeGeneratesCompleteAnimations()
    tests.unrecognizedLayoutFails()
    tests.invalidConventionFailsBeforeGeneratingOutOfBoundsFrames()
}

private struct PetdexAnimationMappingProviderTests {
    func recognizesEightByNineConventionAndDerivesFrameSize() {
        let convention = parseConvention(imageSize: CGSizeCodable(width: 1536, height: 1872))

        expect(convention.columns == 8, "Petdex convention should use 8 columns")
        expect(convention.rows == 9, "Petdex convention should use 9 rows")
        expect(convention.frameSize == CGSizeCodable(width: 192, height: 208), "1536x1872 should derive 192x208 frames")
        expect(convention.stateRows[.idle] == 0, "idle should map to row 0")
        expect(convention.stateRows[.dragging] == 6, "dragging should map to row 6")
        expect(convention.framesPerState[.walking] == 8, "walking should use all 8 columns")
    }

    func generatesAllMVPStateClips() {
        let convention = parseConvention(imageSize: CGSizeCodable(width: 1536, height: 1872))
        let clips = parseClips(convention: convention)

        expect(Set(clips.keys) == Set(PetState.allCases), "all MVP states should have animation clips")
        for state in PetState.allCases {
            guard let clip = clips[state] else {
                fail("missing clip for \(state.rawValue)")
            }
            expect(!clip.frames.isEmpty, "\(state.rawValue) should have at least one frame")
        }
    }

    func framesStayInsideSpritesheetBounds() {
        let convention = parseConvention(imageSize: CGSizeCodable(width: 1536, height: 1872))
        let clips = parseClips(convention: convention)

        for (state, clip) in clips {
            for frame in clip.frames {
                expect(frame.column >= 0, "\(state.rawValue) frame column should be non-negative")
                expect(frame.row >= 0, "\(state.rawValue) frame row should be non-negative")
                expect(frame.column < convention.columns, "\(state.rawValue) frame column should be inside grid")
                expect(frame.row < convention.rows, "\(state.rawValue) frame row should be inside grid")
            }
        }
    }

    func nonLoopingStatesReturnToIdle() {
        let convention = parseConvention(imageSize: CGSizeCodable(width: 1536, height: 1872))
        let clips = parseClips(convention: convention)

        let loopingStates: Set<PetState> = [.idle, .walking, .sleeping, .dragging]
        for state in PetState.allCases {
            guard let clip = clips[state] else {
                fail("missing clip for \(state.rawValue)")
            }
            if loopingStates.contains(state) {
                expect(clip.loop, "\(state.rawValue) should loop")
                expect(clip.nextState == nil, "\(state.rawValue) looping clip should not force nextState")
                expect(clip.frameDurationMs == DefaultPetdexAnimationMappingProvider.loopingFrameDurationMs, "\(state.rawValue) should use looping duration")
            } else {
                expect(!clip.loop, "\(state.rawValue) should be a one-shot clip")
                expect(clip.nextState == .idle, "\(state.rawValue) should return to idle")
                expect(clip.frameDurationMs == DefaultPetdexAnimationMappingProvider.oneShotFrameDurationMs, "\(state.rawValue) should use one-shot duration")
            }
        }
    }

    func myCatV3LargeGeneratesCompleteAnimations() {
        let manifest = PetdexManifest(
            id: "my-cat-v3-large",
            displayName: "Beibei",
            description: "A Petdex cat package.",
            spritesheetPath: "spritesheet.webp"
        )
        let provider = DefaultPetdexAnimationMappingProvider()

        let convention: PetdexSpriteSheetConvention
        do {
            convention = try provider.convention(
                for: manifest,
                imageSize: CGSizeCodable(width: 1536, height: 1872)
            )
        } catch {
            fail("my-cat-v3-large convention should be recognized: \(error)")
        }

        let clips = parseClips(convention: convention)
        expect(clips.count == PetState.allCases.count, "my-cat-v3-large should generate all seven animation clips")
        expect(clips[.idle]?.frames.first == SpriteFrame(column: 0, row: 0), "idle should start at first frame")
    }

    func unrecognizedLayoutFails() {
        let manifest = PetdexManifest(
            id: "bad-layout",
            displayName: "Bad",
            description: "",
            spritesheetPath: "spritesheet.webp"
        )

        expectInvalidLayout {
            _ = try DefaultPetdexAnimationMappingProvider().convention(
                for: manifest,
                imageSize: CGSizeCodable(width: 1537, height: 1872)
            )
        }
    }

    func invalidConventionFailsBeforeGeneratingOutOfBoundsFrames() {
        let convention = PetdexSpriteSheetConvention(
            columns: 8,
            rows: 9,
            frameSize: CGSizeCodable(width: 192, height: 208),
            stateRows: [
                .idle: 0,
                .walking: 1,
                .sleeping: 2,
                .happy: 3,
                .eating: 4,
                .jumping: 5,
                .dragging: 9
            ],
            framesPerState: Dictionary(uniqueKeysWithValues: PetState.allCases.map { ($0, 8) }),
            frameDurationsMs: Dictionary(uniqueKeysWithValues: PetState.allCases.map { ($0, 160) })
        )

        expectInvalidLayout {
            _ = try DefaultPetdexAnimationMappingProvider().animationClips(for: convention)
        }
    }

    private func parseConvention(imageSize: CGSizeCodable) -> PetdexSpriteSheetConvention {
        let manifest = PetdexManifest(
            id: "test-pet",
            displayName: "Test Pet",
            description: "",
            spritesheetPath: "spritesheet.webp"
        )

        do {
            return try DefaultPetdexAnimationMappingProvider().convention(
                for: manifest,
                imageSize: imageSize
            )
        } catch {
            fail("expected convention to parse: \(error)")
        }
    }

    private func parseClips(convention: PetdexSpriteSheetConvention) -> [PetState: ManifestAnimationClip] {
        do {
            return try DefaultPetdexAnimationMappingProvider().animationClips(for: convention)
        } catch {
            fail("expected clips to generate: \(error)")
        }
    }

    private func expectInvalidLayout(operation: () throws -> Void) {
        do {
            try operation()
            fail("expected invalid spritesheet layout")
        } catch PetdexImportError.invalidSpritesheetLayout {
        } catch {
            fail("expected invalidSpritesheetLayout, got \(error)")
        }
    }
}
