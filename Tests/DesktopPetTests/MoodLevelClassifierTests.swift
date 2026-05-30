import Foundation
import DesktopPet

func runMoodLevelClassifierTests() {
    let tests = MoodLevelClassifierTests()
    tests.exposesThresholdConstants()
    tests.classifiesHighAtAndAboveHighThreshold()
    tests.classifiesMediumAtLowThresholdAndBelowHighThreshold()
    tests.classifiesLowBelowLowThreshold()
}

private struct MoodLevelClassifierTests {
    func exposesThresholdConstants() {
        expect(MoodLevelClassifier.highThreshold == 0.66, "high threshold should be public and fixed at 0.66")
        expect(MoodLevelClassifier.lowThreshold == 0.33, "low threshold should be public and fixed at 0.33")
    }

    func classifiesHighAtAndAboveHighThreshold() {
        expect(MoodLevelClassifier.level(for: 0.66) == .high, "mood 0.66 should be high")
        expect(MoodLevelClassifier.level(for: 1.0) == .high, "mood 1.0 should be high")
    }

    func classifiesMediumAtLowThresholdAndBelowHighThreshold() {
        expect(MoodLevelClassifier.level(for: 0.33) == .medium, "mood 0.33 should be medium")
        expect(MoodLevelClassifier.level(for: 0.65) == .medium, "mood below 0.66 should be medium")
        expect(MoodLevelClassifier.level(for: 0.5) == .medium, "mood 0.5 should be medium")
    }

    func classifiesLowBelowLowThreshold() {
        expect(MoodLevelClassifier.level(for: 0.32) == .low, "mood 0.32 should be low")
        expect(MoodLevelClassifier.level(for: 0.0) == .low, "mood 0.0 should be low")
    }
}
