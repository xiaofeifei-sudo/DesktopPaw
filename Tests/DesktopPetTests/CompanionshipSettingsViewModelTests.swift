import Foundation
import DesktopPet

@MainActor
func runCompanionshipSettingsViewModelTests() {
    let tests = CompanionshipSettingsViewModelTests()
    tests.defaultStateShowsAcquaintanceLevel()
    tests.levelDisplayTextReflectsRelationshipLevel()
    tests.progressTextShowsPointsAndNextLevel()
    tests.progressFractionCalculatedCorrectly()
    tests.setMaxLevelShowsMaxProgress()
    tests.setRelationshipPromptsEnabledFiresCallback()
    tests.updateRelationshipRefreshesPublishedState()
    tests.updatePreferencesRefreshesPublishedState()
    tests.quietForOneHourFiresCallback()
    tests.clearQuietModeFiresCallback()
    tests.resetRelationshipFiresCallback()
    tests.resetUpdatesDisplayedLevel()
    tests.setPetNicknameFiresCallback()
    tests.setUserNicknameFiresCallback()
    tests.petNicknameIsScopedToCurrentPetId()
}

@MainActor
private struct CompanionshipSettingsViewModelTests {
    func defaultStateShowsAcquaintanceLevel() {
        let model = CompanionshipSettingsViewModel()

        expect(model.relationship.currentLevel == .acquaintance, "default relationship should be Lv.1 acquaintance")
        expect(model.relationship.intimacyPoints == 0, "default intimacy points should be 0")
        expect(model.preferences.showRelationshipPrompts, "default should show relationship prompts")
        expect(model.quietState == .inactive, "default quiet state should be inactive")
    }

    func levelDisplayTextReflectsRelationshipLevel() {
        let model = CompanionshipSettingsViewModel(
            relationship: RelationshipSnapshot(intimacyPoints: 120, currentLevel: .familiar)
        )

        expect(model.levelDisplayText == "Lv.2 熟悉", "level display should show level number and name")
    }

    func progressTextShowsPointsAndNextLevel() {
        let model = CompanionshipSettingsViewModel(
            relationship: RelationshipSnapshot(intimacyPoints: 120, currentLevel: .familiar)
        )

        expect(model.progressText == "120 / 250", "progress text should show current points and next level threshold")
    }

    func progressFractionCalculatedCorrectly() {
        let model = CompanionshipSettingsViewModel(
            relationship: RelationshipSnapshot(intimacyPoints: 175, currentLevel: .familiar)
        )

        let expectedFraction = Double(175 - 100) / Double(250 - 100)
        expect(abs(model.progressFraction - expectedFraction) < 0.001, "progress fraction should be (points - min) / (next - min)")
    }

    func setMaxLevelShowsMaxProgress() {
        let model = CompanionshipSettingsViewModel(
            relationship: RelationshipSnapshot(intimacyPoints: 950, currentLevel: .bonded)
        )

        expect(model.progressText == "Max", "max level should show 'Max' progress text")
        expect(abs(model.progressFraction - 1.0) < 0.001, "max level should have 1.0 progress fraction")
    }

    func setRelationshipPromptsEnabledFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var receivedValue: Bool?

        model.onRelationshipPromptsChanged = { receivedValue = $0 }

        model.setRelationshipPromptsEnabled(false)

        expect(receivedValue == false, "callback should receive the new value")
        expect(!model.preferences.showRelationshipPrompts, "preferences should be updated locally")
    }

    func updateRelationshipRefreshesPublishedState() {
        let model = CompanionshipSettingsViewModel()
        let newSnapshot = RelationshipSnapshot(intimacyPoints: 260, currentLevel: .close)

        model.updateRelationship(newSnapshot)

        expect(model.relationship.intimacyPoints == 260, "relationship should be updated")
        expect(model.relationship.currentLevel == .close, "relationship level should be updated")
    }

    func updatePreferencesRefreshesPublishedState() {
        let model = CompanionshipSettingsViewModel()
        var prefs = CompanionPreferences()
        prefs.showRelationshipPrompts = false
        prefs.userNickname = "Alex"

        model.updatePreferences(prefs)

        expect(!model.preferences.showRelationshipPrompts, "preferences should be updated")
        expect(model.preferences.userNickname == "Alex", "user nickname should be reflected")
    }

    func quietForOneHourFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var called = false

        model.onQuietForOneHour = { called = true }
        model.quietForOneHour()

        expect(called, "quietForOneHour callback should fire")
    }

    func clearQuietModeFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var called = false

        model.onClearQuietMode = { called = true }
        model.clearQuietMode()

        expect(called, "clearQuietMode callback should fire")
    }

    func resetRelationshipFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var called = false

        model.onResetRelationship = { called = true }
        model.resetRelationship()

        expect(called, "resetRelationship callback should fire")
    }

    func resetUpdatesDisplayedLevel() {
        let model = CompanionshipSettingsViewModel(
            relationship: RelationshipSnapshot(intimacyPoints: 500, currentLevel: .trusted)
        )

        model.updateRelationship(RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance))

        expect(model.relationship.intimacyPoints == 0, "reset should show 0 points")
        expect(model.relationship.currentLevel == .acquaintance, "reset should show Lv.1")
        expect(model.levelDisplayText == "Lv.1 初识", "reset should show Lv.1 display text")
        expect(model.progressText != "Max", "reset should not show Max progress")
    }

    func setPetNicknameFiresCallback() {
        let model = CompanionshipSettingsViewModel(currentPetId: "pet-a")
        var receivedNickname: String?

        model.onPetNicknameChanged = { receivedNickname = $0 }
        model.setPetNickname("Mochi")

        expect(receivedNickname == "Mochi", "callback should receive pet nickname")
        expect(model.preferences.petNicknamesByPetId["pet-a"] == "Mochi", "preferences should be updated")
    }

    func setUserNicknameFiresCallback() {
        let model = CompanionshipSettingsViewModel()
        var receivedNickname: String?

        model.onUserNicknameChanged = { receivedNickname = $0 }
        model.setUserNickname("Alex")

        expect(receivedNickname == "Alex", "callback should receive user nickname")
        expect(model.preferences.userNickname == "Alex", "preferences should be updated")
    }

    func petNicknameIsScopedToCurrentPetId() {
        let model = CompanionshipSettingsViewModel(currentPetId: "pet-a")
        model.setPetNickname("Mochi")

        expect(model.currentPetNickname == "Mochi", "current pet nickname should be Mochi")

        model.updatePetId("pet-b")
        expect(model.currentPetNickname == nil, "pet-b should have no nickname")
        expect(model.preferences.petNicknamesByPetId["pet-a"] == "Mochi", "pet-a nickname should still exist in preferences")
    }
}
