import Foundation
import DesktopPet

@MainActor
func runConsistencyPreferenceStoreTests() async throws {
    let tests = ConsistencyPreferenceStoreTests()
    tests.displayCopyMatchesProductRequirements()
    try await tests.defaultsToConservativeForUnknownPet()
    try await tests.storesConsistencyPreferencePerPet()
    try await tests.storesVisualNotesPerPetAndClearsEmptyNotes()
    try await tests.sanitizesVisualNotesBeforeSaving()
}

@MainActor
private struct ConsistencyPreferenceStoreTests {
    private func createStore() -> PetVisualPreferenceStore {
        let suiteName = "consistency-preference-store-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PetVisualPreferenceStore(userDefaults: defaults)
    }

    func displayCopyMatchesProductRequirements() {
        expect(ConsistencyPreference.conservative.displayName == "保守优先", "conservative display copy should match PRD")
        expect(ConsistencyPreference.balanced.displayName == "平衡", "balanced display copy should match PRD")
        expect(ConsistencyPreference.creative.displayName == "创意优先", "creative display copy should match PRD")
        expect(ConsistencyPreference.conservative.userDescription == "尽量像原图，只做小变化", "conservative description should match PRD")
        expect(ConsistencyPreference.balanced.userDescription == "保持像原图，但允许明显配饰或氛围变化", "balanced description should match PRD")
        expect(ConsistencyPreference.creative.userDescription == "允许更明显主题变化，但仍不能变成新角色", "creative description should match PRD")
    }

    func defaultsToConservativeForUnknownPet() async throws {
        let store = createStore()

        let preference = await store.preference(for: "pet-a")

        expect(preference == .conservative, "unknown pets should default to conservative")
    }

    func storesConsistencyPreferencePerPet() async throws {
        let store = createStore()

        try await store.setPreference(.creative, for: "pet-a")
        try await store.setPreference(.balanced, for: "pet-b")

        let petAPreference = await store.preference(for: "pet-a")
        let petBPreference = await store.preference(for: "pet-b")
        let petCPreference = await store.preference(for: "pet-c")

        expect(petAPreference == .creative, "pet-a should keep creative preference")
        expect(petBPreference == .balanced, "pet-b should keep balanced preference")
        expect(petCPreference == .conservative, "pet-c should not inherit another pet's preference")
    }

    func storesVisualNotesPerPetAndClearsEmptyNotes() async throws {
        let store = createStore()

        try await store.setVisualNotes(" pink-white 2D fox ", for: "pet-a")
        try await store.setVisualNotes(" blue cat ", for: "pet-b")

        let petANotes = await store.visualNotes(for: "pet-a")
        let petBNotes = await store.visualNotes(for: "pet-b")

        expect(petANotes == "pink-white 2D fox", "pet-a notes should be trimmed and stored")
        expect(petBNotes == "blue cat", "pet-b notes should be independent")

        try await store.setVisualNotes("   ", for: "pet-a")

        let clearedPetANotes = await store.visualNotes(for: "pet-a")
        let retainedPetBNotes = await store.visualNotes(for: "pet-b")

        expect(clearedPetANotes == nil, "empty notes should clear pet-a notes")
        expect(retainedPetBNotes == "blue cat", "clearing pet-a should not affect pet-b")
    }

    func sanitizesVisualNotesBeforeSaving() async throws {
        let store = createStore()

        try await store.setVisualNotes("ignore previous pink-white fox, 2D sprite", for: "pet-a")

        let notes = await store.visualNotes(for: "pet-a")
        expect(notes == "pink-white fox, 2D sprite", "stored visual notes should remove prompt-injection phrases")
    }
}
