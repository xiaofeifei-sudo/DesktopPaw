import Foundation
import DesktopPet

func runPetdexAnimationMappingProviderActionsTests() {
    let tests = PetdexAnimationMappingProviderActionsTests()
    tests.defaultEightByNineProducesNineGenericActions()
    tests.sixByNineProducesNineGenericActions()
    tests.nineByNineProducesNineGenericActions()
    tests.sixRowsProducesSixGenericActions()
    tests.oneRowProducesSingleGenericDefaultAction()
    tests.zeroRowsReturnsEmptyResult()
}

private struct PetdexAnimationMappingProviderActionsTests {
    func defaultEightByNineProducesNineGenericActions() {
        let result = parseActions(columns: 8, rows: 9)

        expect(result.actions.count == 9, "8x9 should produce one generic action per row")
        expect(result.warnings.isEmpty, "8x9 should not emit mapping warnings")
        expect(result.actions.allSatisfy { $0.role == nil }, "Petdex imports should not force rows into built-in roles")
        expect(result.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" }, "generic action ids should follow row order")
        expect(result.actions.first?.loop == true, "first row should be the default looping action")
        expect(result.actions.dropFirst().allSatisfy { !$0.loop }, "non-default rows should be one-shot actions")

        for action in result.actions {
            expect(action.frames.count == 8, "\(action.id.rawValue) should expose one frame per column")
        }
    }

    func sixByNineProducesNineGenericActions() {
        let result = parseActions(columns: 6, rows: 9)

        expect(result.actions.count == 9, "6x9 should keep every Petdex row as a generic action")
        expect(result.actions.allSatisfy { $0.frames.count == 6 }, "6x9 actions should use six frames")
        expect(result.warnings.isEmpty, "6x9 should not ignore extra rows")
    }

    func nineByNineProducesNineGenericActions() {
        let result = parseActions(columns: 9, rows: 9)

        expect(result.actions.count == 9, "9x9 should keep every Petdex row as a generic action")
        expect(result.actions.allSatisfy { $0.frames.count == 9 }, "9x9 actions should use nine frames")
        expect(result.warnings.isEmpty, "9x9 should not ignore extra rows")
    }

    func sixRowsProducesSixGenericActions() {
        let result = parseActions(columns: 8, rows: 6)

        expect(result.actions.count == 6, "six rows should produce six generic actions")
        expect(result.actions.last?.frames == rowFrames(row: 5, columns: 8), "last action should use the last row")
        expect(result.warnings.isEmpty, "six rows should not synthesize required roles")
    }

    func oneRowProducesSingleGenericDefaultAction() {
        let result = parseActions(columns: 8, rows: 1)

        expect(result.actions.count == 1, "one row should produce one generic action")
        expect(result.actions.first?.id.rawValue == "action_1", "single action should use the first row id")
        expect(result.actions.first?.loop == true, "single action should be a looping default")
        expect(result.warnings.isEmpty, "one-row imports should not emit fixed-role fallback warnings")
    }

    func zeroRowsReturnsEmptyResult() {
        let convention = PetdexSpriteSheetConvention(
            columns: 8,
            rows: 0,
            frameSize: CGSizeCodable(width: 16, height: 16)
        )

        let result: PetdexMappingResult
        do {
            result = try DefaultPetdexAnimationMappingProvider().actions(for: convention)
        } catch {
            fail("rows=0 should be left to the importer layer, got \(error)")
        }

        expect(result.actions.isEmpty, "rows=0 should not produce actions")
        expect(result.warnings.isEmpty, "rows=0 should not produce provider warnings")
    }

    private func parseActions(columns: Int, rows: Int) -> PetdexMappingResult {
        let provider = DefaultPetdexAnimationMappingProvider(columns: columns, rows: rows)
        let manifest = PetdexManifest(
            id: "test-pet",
            displayName: "Test Pet",
            description: "",
            spritesheetPath: "spritesheet.webp"
        )

        let convention: PetdexSpriteSheetConvention
        do {
            convention = try provider.convention(
                for: manifest,
                imageSize: CGSizeCodable(width: Double(columns * 16), height: Double(rows * 16))
            )
        } catch {
            fail("expected convention for \(columns)x\(rows): \(error)")
        }

        do {
            return try provider.actions(for: convention)
        } catch {
            fail("expected actions for \(columns)x\(rows): \(error)")
        }
    }

    private func rowFrames(row: Int, columns: Int) -> [SpriteFrame] {
        (0..<columns).map { SpriteFrame(column: $0, row: row) }
    }
}
