import Foundation
import DesktopPet

func runPetdexExtraRowInferrerTests() {
    let tests = PetdexExtraRowInferrerTests()
    tests.defaultGridProducesTwoExtras()
    tests.fewerRowsProducesNoExtras()
    tests.differentColumnsProducesNoExtras()
    tests.moreRowsProducesNoExtras()
    tests.extrasFramesCoverEachColumn()
    tests.extrasReturnToIdleAfterPlayback()
    tests.extrasUseOneShotDurationAndDoNotLoop()
    tests.zeroColumnsProducesNoExtras()
    tests.partialSkipRowsProducesNoExtras()
}

private struct PetdexExtraRowInferrerTests {
    private let defaultSkipRows: Set<Int> = [0, 1, 2, 3, 4, 5, 6]

    func defaultGridProducesTwoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 8,
            skipRows: defaultSkipRows
        )

        expect(extras.count == 2, "8x9 with skipRows {0..6} should yield 2 extras")
        expect(extras[0].id.rawValue == "extra_1", "first extra id should be extra_1")
        expect(extras[1].id.rawValue == "extra_2", "second extra id should be extra_2")
        expect(extras[0].role == nil, "extra_1 should not bind to a contract role")
        expect(extras[1].role == nil, "extra_2 should not bind to a contract role")
        expect(extras[0].tags.isEmpty, "extra_1 should have no tags by default")
        expect(extras[1].tags.isEmpty, "extra_2 should have no tags by default")
        expect(extras[0].displayName == "自定义动作 1", "extra_1 should use Phase 1 fallback display name")
        expect(extras[1].displayName == "自定义动作 2", "extra_2 should use Phase 1 fallback display name")
    }

    func fewerRowsProducesNoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 6,
            columns: 9,
            skipRows: defaultSkipRows
        )

        expect(extras.isEmpty, "non 8x9 grid (6 rows) should produce no extras")
    }

    func differentColumnsProducesNoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 9,
            skipRows: defaultSkipRows
        )

        expect(extras.isEmpty, "non 8x9 grid (9 columns) should produce no extras")
    }

    func moreRowsProducesNoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 10,
            columns: 8,
            skipRows: defaultSkipRows
        )

        expect(extras.isEmpty, "non 8x9 grid (10 rows) should produce no extras")
    }

    func extrasFramesCoverEachColumn() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 8,
            skipRows: defaultSkipRows
        )

        guard extras.count == 2 else {
            fail("expected 2 extras for default grid")
        }

        let firstFrames = extras[0].frames
        expect(firstFrames.count == 8, "extra_1 should expose one frame per column")
        for (column, frame) in firstFrames.enumerated() {
            expect(frame.row == 7, "extra_1 frame at index \(column) should reference row 7")
            expect(frame.column == column, "extra_1 frame at index \(column) should reference column \(column)")
        }

        let secondFrames = extras[1].frames
        expect(secondFrames.count == 8, "extra_2 should expose one frame per column")
        for (column, frame) in secondFrames.enumerated() {
            expect(frame.row == 8, "extra_2 frame at index \(column) should reference row 8")
            expect(frame.column == column, "extra_2 frame at index \(column) should reference column \(column)")
        }
    }

    func extrasReturnToIdleAfterPlayback() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 8,
            skipRows: defaultSkipRows
        )

        for extra in extras {
            expect(extra.nextActionId == ActionId.idle, "\(extra.id.rawValue) should return to idle after one-shot")
        }
    }

    func extrasUseOneShotDurationAndDoNotLoop() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 8,
            skipRows: defaultSkipRows
        )

        for extra in extras {
            expect(extra.loop == false, "\(extra.id.rawValue) should not loop")
            expect(extra.frameDurationMs == 120, "\(extra.id.rawValue) should use Petdex one-shot duration")
        }
    }

    func zeroColumnsProducesNoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 0,
            skipRows: defaultSkipRows
        )

        expect(extras.isEmpty, "zero columns should yield no extras even on default rows")
    }

    func partialSkipRowsProducesNoExtras() {
        let extras = DefaultPetdexExtraRowInferrer().inferExtras(
            rows: 9,
            columns: 8,
            skipRows: [0, 1, 2]
        )

        expect(extras.isEmpty, "non-default skip rows should be treated as a non-default layout")
    }
}
