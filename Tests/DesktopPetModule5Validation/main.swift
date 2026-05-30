import DesktopPet
import Foundation

@MainActor
func runModule5Validation() {
    print("=== Module 5 Validation: MemoryManagementUI ===\n")

    let store = AIMemoryStore()
    let petId = "test-pet-module5"
    let emotionalStore = EmotionalModelStore()

    // Clean up any leftover data from previous runs
    try? store.clearAll(petId: petId)
    store.setMemoryEnabled(true, petId: petId)

    var allPassed = true

    // 5.1 ViewModel Initialization
    print("5.1 ViewModel Initialization...")
    let vm = MemoryManagementViewModel(
        memoryStore: store,
        emotionalModelStore: emotionalStore,
        petId: petId
    )
    assert(vm.memories.isEmpty, "Should start empty")
    assert(vm.filteredMemories.isEmpty, "Filtered should be empty")
    assert(vm.groupedMemories.isEmpty, "Grouped should be empty")
    assert(vm.searchText.isEmpty, "Search should start empty")
    assert(vm.selectedCategory == nil, "Category filter should start nil")
    print("  PASSED: init, empty defaults")

    // 5.2 Add Memory
    print("5.2 Add Memory...")
    vm.addMemory(content: "  I like cats  ", category: .preference)
    assert(vm.memories.count == 1, "Should have 1 memory after add")
    assert(vm.memories[0].content == "I like cats", "Content should be trimmed")
    assert(vm.memories[0].category == .preference, "Category should be preference")
    assert(vm.memories[0].source == .userProvided, "Source should be userProvided")
    assert(vm.memories[0].importance == 0.9, "Importance should default to 0.9")
    print("  PASSED: add, trim, defaults")

    // Add more memories for grouping
    vm.addMemory(content: "Call me Xiaoming", category: .nickname)
    vm.addMemory(content: "Graduated in May", category: .milestone)
    vm.addMemory(content: "My cat is named Orange", category: .custom)
    vm.addMemory(content: "Work late hours", category: .routine)
    vm.addMemory(content: "Feeling stressed lately", category: .emotion)
    vm.addMemory(content: "Chat about work today", category: .interaction)
    vm.addMemory(content: "Like cool colors", category: .preference)
    assert(vm.memories.count == 8, "Should have 8 memories")
    print("  PASSED: add multiple categories")

    // 5.3 Grouped Display
    print("5.3 Grouped Display...")
    let groups = vm.groupedMemories
    assert(!groups.isEmpty, "Should have groups")
    let groupCategories = groups.map(\.category)
    // Should follow display order: nickname, milestone, custom, preference, routine, emotion, interaction
    assert(groupCategories[0] == .nickname, "First group should be nickname")
    assert(groupCategories[1] == .milestone, "Second group should be milestone")
    assert(groupCategories[2] == .custom, "Third group should be custom")
    assert(groupCategories[3] == .preference, "Fourth group should be preference")
    // Preference should have 2 items
    let prefGroup = groups.first { $0.category == .preference }
    assert(prefGroup?.memories.count == 2, "Preference should have 2 items")
    // Items within group should be sorted by updatedAt descending
    if let prefMemories = prefGroup?.memories, prefMemories.count >= 2 {
        assert(prefMemories[0].updatedAt >= prefMemories[1].updatedAt, "Should be sorted by time desc")
    }
    print("  PASSED: grouping, sort order, time sorting")

    // 5.4 Search
    print("5.4 Search...")
    vm.searchText = "cat"
    let catResults = vm.filteredMemories
    assert(catResults.count == 2, "Should find 2 results for 'cat' (like cats + cat named Orange)")
    vm.searchText = ""
    assert(vm.filteredMemories.count == 8, "Should reset to all 8")
    print("  PASSED: keyword search, reset")

    // 5.5 Category Filter
    print("5.5 Category Filter...")
    vm.selectedCategory = .preference
    assert(vm.filteredMemories.count == 2, "Should filter to 2 preferences")
    assert(vm.filteredMemories.allSatisfy { $0.category == .preference }, "All should be preference")
    vm.selectedCategory = nil
    assert(vm.filteredMemories.count == 8, "Should reset to all 8")
    print("  PASSED: category filter, reset")

    // 5.6 Search + Filter Combined
    print("5.6 Search + Filter Combined...")
    vm.searchText = "cat"
    vm.selectedCategory = .custom
    let combined = vm.filteredMemories
    assert(combined.count == 1, "Should find 1 custom memory about cat")
    assert(combined[0].category == .custom, "Should be custom category")
    vm.searchText = ""
    vm.selectedCategory = nil
    print("  PASSED: combined search + filter")

    // 5.7 Delete
    print("5.7 Delete...")
    let toDelete = vm.memories.first { $0.category == .interaction }!
    vm.delete(toDelete)
    assert(vm.memories.count == 7, "Should have 7 after delete")
    assert(!vm.memories.contains(where: { $0.id == toDelete.id }), "Deleted memory should be gone")
    print("  PASSED: single delete")

    // 5.8 Batch Delete by Category
    print("5.8 Batch Delete by Category...")
    vm.deleteByCategory(.preference)
    assert(vm.memories.count == 5, "Should have 5 after batch delete")
    assert(!vm.memories.contains(where: { $0.category == .preference }), "No preferences left")
    print("  PASSED: batch delete by category")

    // 5.9 Clear All
    print("5.9 Clear All...")
    vm.clearAll()
    assert(vm.memories.isEmpty, "Should be empty after clear")
    assert(vm.filteredMemories.isEmpty, "Filtered should be empty")
    assert(vm.groupedMemories.isEmpty, "Grouped should be empty")
    print("  PASSED: clear all")

    // 5.10 Empty State
    print("5.10 Empty State...")
    assert(vm.filteredMemories.isEmpty, "Empty after clear")
    assert(vm.groupedMemories.isEmpty, "No groups when empty")
    vm.searchText = "test"
    assert(vm.filteredMemories.isEmpty, "Search on empty returns empty")
    vm.searchText = ""
    print("  PASSED: empty state behavior")

    // 5.11 Statistics
    print("5.11 Statistics...")
    vm.addMemory(content: "Stat test 1", category: .nickname)
    vm.addMemory(content: "Stat test 2", category: .nickname)
    vm.addMemory(content: "Stat test 3", category: .milestone)
    let stats = vm.statistics
    assert(stats != nil, "Statistics should be non-nil")
    assert(stats!.totalCount == 3, "Total should be 3")
    assert(stats!.categoryCounts[.nickname] == 2, "Nickname count should be 2")
    assert(stats!.categoryCounts[.milestone] == 1, "Milestone count should be 1")
    assert(stats!.utilizationRate > 0, "Utilization should be > 0")
    print("  PASSED: statistics, category counts, utilization")

    // 5.12 Emotional Model
    print("5.12 Emotional Model...")
    assert(vm.emotionalModel != nil, "Should load default emotional model")
    assert(!vm.hasEmotionalData, "Default model should not have emotional data")
    // Save a model with data and reload
    var model = AIEmotionalModel()
    model.totalSessions = 5
    model.currentMood = .happy
    try? emotionalStore.saveModel(model, petId: petId)
    vm.loadData()
    assert(vm.hasEmotionalData, "Should have emotional data after saving model")
    assert(vm.emotionalModel?.currentMood == .happy, "Mood should be happy")
    print("  PASSED: emotional model loading, data detection")

    // 5.13 Edit Memory
    print("5.13 Edit Memory...")
    let toEdit = vm.memories.first { $0.category == .milestone }!
    vm.startEditing(toEdit)
    assert(vm.editingMemory != nil, "Should be editing")
    assert(vm.editedContent == toEdit.content, "Edited content should match original")
    vm.editedContent = "Updated milestone"
    vm.saveEditing()
    assert(vm.editingMemory == nil, "Should stop editing after save")
    let updated = vm.memories.first { $0.id == toEdit.id }!
    assert(updated.content == "Updated milestone", "Content should be updated")
    vm.cancelEditing()
    assert(vm.editingMemory == nil, "Cancel should clear editing state")
    print("  PASSED: edit, save, cancel")

    // 5.14 PetId Update
    print("5.14 PetId Update...")
    vm.updatePetId("new-pet-id")
    assert(vm.petId == "new-pet-id", "PetId should be updated")
    vm.updatePetId(petId)
    print("  PASSED: petId update")

    // 5.15 Add Empty/Whitespace
    print("5.15 Add Empty/Whitespace...")
    let countBefore = vm.memories.count
    vm.addMemory(content: "   ", category: .custom)
    assert(vm.memories.count == countBefore, "Should not add whitespace-only content")
    vm.addMemory(content: "", category: .custom)
    assert(vm.memories.count == countBefore, "Should not add empty content")
    print("  PASSED: empty/whitespace rejection")

    // 5.16 Display Name Extensions
    print("5.16 Display Name Extensions...")
    assert(!AIMemoryCategory.preference.displayName.isEmpty, "Category display name should not be empty")
    assert(!AIMemorySource.aiExtracted.displayName.isEmpty, "Source display name should not be empty")
    assert(!EmotionalMood.happy.displayName.isEmpty, "Mood display name should not be empty")
    assert(!EmotionalMood.happy.emoji.isEmpty, "Mood emoji should not be empty")
    assert(!MoodTrend.improving.displayName.isEmpty, "Trend display name should not be empty")
    assert(!RelationshipPhase.familiar.displayName.isEmpty, "Phase display name should not be empty")
    print("  PASSED: display name extensions")

    // Cleanup
    try? store.clearAll(petId: petId)

    if allPassed {
        print("\n=== Module 5 All Validations PASSED ===")
    }
}

@main
struct Module5Validation {
    static func main() async {
        await runModule5Validation()
    }
}
