import Foundation
import DesktopPet

@MainActor
func runPetVisualPreferenceStoreTests() {
    let tests = PetVisualPreferenceStoreTests()
    tests.loadDefaultsReturnsEmptyPreferences()
    tests.saveAndLoadPreferences()
    tests.setPreferredThemes()
    tests.setDislikedContent()
    tests.setActiveFavoriteId()
    tests.setFavoriteName()
    tests.setFavoriteNameRemovesOnEmpty()
    tests.clearFavoriteName()
}

@MainActor
private struct PetVisualPreferenceStoreTests {
    private func createStore() -> PetVisualPreferenceStore {
        let defaults = UserDefaults(suiteName: "test-pet-visual-prefs-\(UUID().uuidString)")!
        return PetVisualPreferenceStore(userDefaults: defaults)
    }

    func loadDefaultsReturnsEmptyPreferences() {
        let store = createStore()
        let prefs = store.loadPreferences()
        expect(prefs.preferredThemes.isEmpty, "default themes should be empty")
        expect(prefs.dislikedContent.isEmpty, "default disliked content should be empty")
        expect(prefs.activeFavoriteId == nil, "default active favorite should be nil")
        expect(prefs.favoriteNames.isEmpty, "default favorite names should be empty")
    }

    func saveAndLoadPreferences() {
        let store = createStore()
        var prefs = PetVisualPreferences()
        prefs.preferredThemes = [.cute, .warm]
        prefs.dislikedContent = [.exaggeratedDeformation]
        prefs.activeFavoriteId = "fav-1"
        prefs.favoriteNames = ["fav-1": "My Cat Hat"]
        store.savePreferences(prefs)

        let loaded = store.loadPreferences()
        expect(loaded == prefs, "loaded preferences should match saved")
    }

    func setPreferredThemes() {
        let store = createStore()
        store.setPreferredThemes([.quiet, .festival])

        let prefs = store.loadPreferences()
        expect(prefs.preferredThemes == [.quiet, .festival], "themes should be updated")
    }

    func setDislikedContent() {
        let store = createStore()
        store.setDislikedContent([.strongScenes, .tooManyAccessories])

        let prefs = store.loadPreferences()
        expect(prefs.dislikedContent == [.strongScenes, .tooManyAccessories], "disliked content should be updated")
    }

    func setActiveFavoriteId() {
        let store = createStore()
        store.setActiveFavoriteId("fav-2")

        let prefs = store.loadPreferences()
        expect(prefs.activeFavoriteId == "fav-2", "active favorite should be updated")

        store.setActiveFavoriteId(nil)
        let prefs2 = store.loadPreferences()
        expect(prefs2.activeFavoriteId == nil, "active favorite should be cleared")
    }

    func setFavoriteName() {
        let store = createStore()
        store.setFavoriteName("Holiday Hat", forAssetId: "a1")

        let prefs = store.loadPreferences()
        expect(prefs.favoriteNames["a1"] == "Holiday Hat", "favorite name should be set")
    }

    func setFavoriteNameRemovesOnEmpty() {
        let store = createStore()
        store.setFavoriteName("Test", forAssetId: "a2")
        store.setFavoriteName("", forAssetId: "a2")

        let prefs = store.loadPreferences()
        expect(prefs.favoriteNames["a2"] == nil, "empty name should remove entry")
    }

    func clearFavoriteName() {
        let store = createStore()
        store.setFavoriteName("Test", forAssetId: "a3")
        store.setFavoriteName(nil, forAssetId: "a3")

        let prefs = store.loadPreferences()
        expect(prefs.favoriteNames["a3"] == nil, "nil name should remove entry")
    }
}
