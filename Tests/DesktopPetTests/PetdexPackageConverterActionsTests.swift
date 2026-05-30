import Foundation
import DesktopPet

func runPetdexPackageConverterActionsTests() {
    let tests = PetdexPackageConverterActionsTests()
    tests.defaultPetdexActionsAreWrittenToSchemaV2Manifest()
    tests.importWarningsSidecarIsWrittenWhenWarningsArePresent()
    tests.decodedManifestBuildsCatalogWithExtras()
}

private struct PetdexPackageConverterActionsTests {
    func defaultPetdexActionsAreWrittenToSchemaV2Manifest() {
        let converted = convertFixture()
        let decoded = decodeManifest(from: converted)

        expect(decoded.schemaVersion == 2, "Petdex converter should write schemaVersion=2")
        expect(decoded.actions.count == 9, "my-cat-v3-large equivalent package should include 9 actions")
        expect(decoded.actions.allSatisfy { $0.role == nil }, "Petdex actions should stay role-less by default")
        expect(decoded.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" }, "Petdex actions should keep row order")
    }

    func importWarningsSidecarIsWrittenWhenWarningsArePresent() {
        let warning = ActionImportWarning(
            kind: .extraRowsIgnored,
            detail: "2 extra Petdex row(s) ignored",
            actionId: ActionId(rawValue: "extra_1")
        )
        let converted = convertFixture(warnings: [warning])

        guard let data = converted.files[ConvertedPetPackage.importWarningsFileName] else {
            fail("warnings should be written to import-warnings.json")
        }

        do {
            let decoded = try JSONDecoder().decode([ImportWarningSidecarEntry].self, from: data)
            expect(decoded == [ImportWarningSidecarEntry(warning: warning)], "warnings sidecar should round-trip")
        } catch {
            fail("warnings sidecar should decode: \(error)")
        }
    }

    func decodedManifestBuildsCatalogWithExtras() {
        let decoded = decodeManifest(from: convertFixture())

        do {
            let definition = try decoded.petDefinition()
            expect(definition.catalog.actions.count == 9, "catalog should include all Petdex row actions")
            expect(definition.catalog.actionsById[ActionId(rawValue: "action_1")!] != nil, "catalog should include action_1")
            expect(definition.catalog.actionsById[ActionId(rawValue: "action_8")!] != nil, "catalog should include action_8")
            expect(definition.catalog.actionsById[ActionId(rawValue: "action_9")!] != nil, "catalog should include action_9")
        } catch {
            fail("decoded converter manifest should build catalog: \(error)")
        }
    }

    private func convertFixture(warnings: [ActionImportWarning] = []) -> ConvertedPetPackage {
        do {
            return try PetdexPackageConverter(importedAtProvider: { Date(timeIntervalSince1970: 1_778_544_000) })
                .convert(
                    manifest: manifest,
                    spritesheet: spritesheet,
                    actions: actions,
                    warnings: warnings
                )
        } catch {
            fail("Petdex package conversion should succeed: \(error)")
        }
    }

    private func decodeManifest(from converted: ConvertedPetPackage) -> PetPackageManifest {
        guard let data = converted.files[ConvertedPetPackage.manifestFileName] else {
            fail("converted package should contain manifest.json")
        }

        do {
            return try JSONDecoder().decode(PetPackageManifest.self, from: data)
        } catch {
            fail("converted manifest should decode: \(error)")
        }
    }

    private var manifest: PetdexManifest {
        PetdexManifest(
            id: "my-cat-v3-large",
            displayName: "Beibei",
            description: "A Petdex cat package.",
            spritesheetPath: "spritesheet.webp"
        )
    }

    private var spritesheet: ProcessedPetdexSpriteSheet {
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

    private var actions: [Action] {
        let provider = DefaultPetdexAnimationMappingProvider()
        do {
            let convention = try provider.convention(
                for: manifest,
                imageSize: CGSizeCodable(width: 1536, height: 1872)
            )
            return try provider.actions(for: convention).actions
        } catch {
            fail("my-cat-v3-large equivalent action fixture should generate: \(error)")
        }
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
