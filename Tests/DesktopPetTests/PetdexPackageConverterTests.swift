import Foundation
import DesktopPet

func runPetdexPackageConverterTests() {
    let tests = PetdexPackageConverterTests()
    tests.convertedPackageContainsRequiredFiles()
    tests.writesInternalSchemaV2Manifest()
    tests.writesPetdexMetadataIntoManifest()
    tests.writesSpriteSheetAssetFields()
    tests.writesFrameSizeAndSpritesheetLayout()
    tests.writesOneGenericActionPerPetdexRow()
    tests.writesPetdexSourceSidecar()
    tests.writesImportWarningsSidecarWhenWarningsArePresent()
    tests.omitsImportWarningsSidecarWhenWarningsAreEmpty()
    tests.generatedManifestRoundTripsToPetDefinition()
    tests.invalidActionsFailConversion()
    tests.legacyAnimationAdapterRemainsAvailable()
}

private struct PetdexPackageConverterTests {
    func convertedPackageContainsRequiredFiles() {
        let converted = convertFixture()
        let names = Set(converted.files.keys)

        expect(converted.petId == "my-cat-v3-large", "converted petId should match Petdex id")
        expect(names.contains(ConvertedPetPackage.manifestFileName), "converted files should include manifest.json")
        expect(names.contains(ProcessedPetdexSpriteSheet.spritesheetFileName), "converted files should include spritesheet.png")
        expect(names.contains(ProcessedPetdexSpriteSheet.previewFileName), "converted files should include preview.png")
        expect(names.contains(PetdexSourceMetadata.fileName), "converted files should include petdex-source.json")
        expect(converted.files[ProcessedPetdexSpriteSheet.spritesheetFileName] == Data("spritesheet-png".utf8), "spritesheet data should be preserved")
        expect(converted.files[ProcessedPetdexSpriteSheet.previewFileName] == Data("preview-png".utf8), "preview data should be preserved")
    }

    func writesInternalSchemaV2Manifest() {
        let converted = convertFixture()
        expect(converted.manifest.schemaVersion == 2, "Petdex converted manifest should use schema v2")

        let decoded = decodeManifest(from: converted)
        expect(decoded.schemaVersion == 2, "encoded manifest.json should decode with schema v2")
    }

    func writesPetdexMetadataIntoManifest() {
        let manifest = convertFixture().manifest

        expect(manifest.id == "my-cat-v3-large", "manifest id should match Petdex id")
        expect(manifest.displayName == "Beibei", "manifest displayName should match Petdex displayName")
        expect(manifest.description == "A Petdex cat package.", "manifest description should match Petdex description")
    }

    func writesSpriteSheetAssetFields() {
        let manifest = convertFixture().manifest

        expect(manifest.assetKind == .spriteSheet, "converted assetKind should be spriteSheet")
        expect(manifest.asset == ProcessedPetdexSpriteSheet.spritesheetFileName, "converted asset should be spritesheet.png")
        expect(manifest.preview == ProcessedPetdexSpriteSheet.previewFileName, "converted preview should be preview.png")
    }

    func writesFrameSizeAndSpritesheetLayout() {
        let manifest = convertFixture().manifest

        expect(manifest.frameSize == CGSizeCodable(width: 192, height: 208), "converted frame size should come from processed spritesheet")
        expect(manifest.spritesheet == SpriteSheetLayout(columns: 8, rows: 9), "converted spritesheet layout should come from processed spritesheet")
    }

    func writesOneGenericActionPerPetdexRow() {
        let manifest = convertFixture().manifest

        expect(manifest.actions.count == 9, "manifest should include one action for each Petdex row")
        expect(manifest.actions.allSatisfy { $0.role == nil }, "Petdex row actions should not be forced into legacy roles")
        expect(
            manifest.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" },
            "Petdex actions should keep row order with generic ids"
        )
        expect(manifest.actions.first?.loop == true, "first Petdex row should be the looping default action")
        expect(manifest.actions.dropFirst().allSatisfy { !$0.loop }, "remaining Petdex row actions should be one-shot")
        for action in manifest.actions {
            expect(!action.frames.isEmpty, "\(action.id.rawValue) action should have frames")
        }
    }

    func writesPetdexSourceSidecar() {
        let converted = convertFixture()

        expect(converted.sourceMetadata.source == .petdex, "sidecar source should be petdex")
        expect(converted.sourceMetadata.petdexId == "my-cat-v3-large", "sidecar petdex id should match manifest")
        expect(converted.sourceMetadata.originalDisplayName == "Beibei", "sidecar displayName should match manifest")
        expect(converted.sourceMetadata.importedAt == fixedImportDate, "sidecar importedAt should use injected date")

        guard let data = converted.files[PetdexSourceMetadata.fileName] else {
            fail("converted files should include petdex source metadata")
        }

        do {
            let decoded = try JSONDecoder().decode(PetdexSourceMetadata.self, from: data)
            expect(decoded == converted.sourceMetadata, "encoded sidecar should decode back to source metadata")
        } catch {
            fail("petdex-source.json should decode: \(error)")
        }
    }

    func writesImportWarningsSidecarWhenWarningsArePresent() {
        let warning = ActionImportWarning(
            kind: .extraRowsIgnored,
            detail: "2 extra Petdex row(s) ignored",
            role: nil,
            actionId: ActionId(rawValue: "extra_1")
        )
        let converted = convertFixture(warnings: [warning])

        guard let data = converted.files[ConvertedPetPackage.importWarningsFileName] else {
            fail("converted files should include import warnings sidecar")
        }

        do {
            let decoded = try JSONDecoder().decode([ImportWarningSidecarEntry].self, from: data)
            expect(decoded == [ImportWarningSidecarEntry(warning: warning)], "encoded import warnings should decode back to source warnings")
        } catch {
            fail("import-warnings.json should decode: \(error)")
        }
    }

    func omitsImportWarningsSidecarWhenWarningsAreEmpty() {
        let converted = convertFixture(warnings: [])

        expect(converted.files[ConvertedPetPackage.importWarningsFileName] == nil, "empty warnings should not create import-warnings.json")
    }

    func generatedManifestRoundTripsToPetDefinition() {
        let converted = convertFixture()
        let decoded = decodeManifest(from: converted)

        do {
            let definition = try decoded.petDefinition()
            expect(definition.id == "my-cat-v3-large", "definition id should match converted manifest")
            expect(definition.assetKind == .spriteSheet, "definition assetKind should be spriteSheet")
            expect(definition.catalog.actions.count == 9, "definition catalog should retain every Petdex row action")
            expect(definition.catalog.actions.allSatisfy { $0.role == nil }, "definition catalog should keep Petdex actions role-less")
            expect(definition.catalog.actionsById[ActionId(rawValue: "action_8")!] != nil, "definition catalog should retain action_8")
            expect(definition.catalog.actionsById[ActionId(rawValue: "action_9")!] != nil, "definition catalog should retain action_9")
        } catch {
            fail("converted manifest should produce a valid PetDefinition: \(error)")
        }
    }

    func invalidActionsFailConversion() {
        let badAction = Action(
            id: ActionId(rawValue: "bad_frame")!,
            displayName: "Bad Frame",
            role: nil,
            frames: [SpriteFrame(column: 99, row: 99)],
            frameDurationMs: 160,
            loop: true
        )
        let actions = makeActions() + [badAction]

        expectPetdexError(.invalidSpritesheetLayout("converted manifest is not a valid pet definition")) {
            _ = try makeConverter().convert(
                manifest: makeManifest(),
                spritesheet: makeSpritesheet(),
                actions: actions,
                warnings: []
            )
        }
    }

    func legacyAnimationAdapterRemainsAvailable() {
        do {
            let converted = try makeConverter().convert(
                manifest: makeManifest(),
                spritesheet: makeSpritesheet(),
                animations: makeAnimations()
            )
            expect(converted.manifest.schemaVersion == 2, "legacy adapter should still emit schema v2")
            expect(converted.manifest.actions.count == PetState.allCases.count, "legacy adapter should convert seven state animations to actions")
            expect(converted.files[ConvertedPetPackage.importWarningsFileName] == nil, "legacy adapter should not emit warnings sidecar")
        } catch {
            fail("legacy animation adapter should succeed: \(error)")
        }
    }

    private func convertFixture(warnings: [ActionImportWarning] = []) -> ConvertedPetPackage {
        do {
            return try makeConverter().convert(
                manifest: makeManifest(),
                spritesheet: makeSpritesheet(),
                actions: makeActions(),
                warnings: warnings
            )
        } catch {
            fail("Petdex package conversion should succeed: \(error)")
        }
    }

    private func makeConverter() -> PetdexPackageConverter {
        PetdexPackageConverter(importedAtProvider: { fixedImportDate })
    }

    private func makeManifest() -> PetdexManifest {
        PetdexManifest(
            id: "my-cat-v3-large",
            displayName: "Beibei",
            description: "A Petdex cat package.",
            spritesheetPath: "spritesheet.webp"
        )
    }

    private func makeSpritesheet() -> ProcessedPetdexSpriteSheet {
        ProcessedPetdexSpriteSheet(
            spritesheetPNGData: Data("spritesheet-png".utf8),
            previewPNGData: Data("preview-png".utf8),
            pixelSize: CGSizeCodable(width: 1536, height: 1872),
            frameSize: CGSizeCodable(width: 192, height: 208),
            columns: 8,
            rows: 9,
            hasAlpha: true
        )
    }

    private func makeAnimations() -> [PetState: ManifestAnimationClip] {
        let roles: [(PetState, Int)] = [
            (.idle, 0),
            (.walking, 1),
            (.sleeping, 2),
            (.happy, 3),
            (.eating, 4),
            (.jumping, 5),
            (.dragging, 6)
        ]
        return Dictionary(uniqueKeysWithValues: roles.map { state, row in
            let looping = state == .idle || state == .walking || state == .sleeping || state == .dragging
            return (
                state,
                ManifestAnimationClip(
                    frames: (0..<8).map { SpriteFrame(column: $0, row: row) },
                    frameDurationMs: looping
                        ? DefaultPetdexAnimationMappingProvider.loopingFrameDurationMs
                        : DefaultPetdexAnimationMappingProvider.oneShotFrameDurationMs,
                    loop: looping,
                    nextState: looping ? nil : .idle
                )
            )
        })
    }

    private func makeActions() -> [Action] {
        makeMappingResult().actions
    }

    private func makeMappingResult() -> PetdexMappingResult {
        let provider = DefaultPetdexAnimationMappingProvider()
        let convention: PetdexSpriteSheetConvention
        do {
            convention = try provider.convention(
                for: makeManifest(),
                imageSize: CGSizeCodable(width: 1536, height: 1872)
            )
            return try provider.actions(for: convention)
        } catch {
            fail("action fixture should generate: \(error)")
        }
    }

    private func decodeManifest(from converted: ConvertedPetPackage) -> PetPackageManifest {
        guard let data = converted.files[ConvertedPetPackage.manifestFileName] else {
            fail("converted package should contain manifest.json")
        }

        do {
            return try JSONDecoder().decode(PetPackageManifest.self, from: data)
        } catch {
            fail("converted manifest.json should decode: \(error)")
        }
    }

    private func expectPetdexError(
        _ expected: PetdexImportError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            fail("expected Petdex error \(expected)")
        } catch let error as PetdexImportError {
            expect(error == expected, "expected \(expected), got \(error)")
        } catch {
            fail("expected PetdexImportError \(expected), got \(error)")
        }
    }

    private var fixedImportDate: Date {
        Date(timeIntervalSince1970: 1_778_544_000)
    }
}

private struct ImportWarningSidecarEntry: Decodable, Equatable {
    let kind: String
    let detail: String
    let role: ActionRole?
    let actionId: ActionId?

    init(warning: ActionImportWarning) {
        kind = warning.kind.rawValue
        detail = warning.detail
        role = warning.role
        actionId = warning.actionId
    }
}
