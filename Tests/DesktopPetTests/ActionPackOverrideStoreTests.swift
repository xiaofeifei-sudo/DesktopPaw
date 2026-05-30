import Foundation
import DesktopPet

func runActionPackOverrideStoreTests() {
    let tests = ActionPackOverrideStoreTests()
    tests.saveAndLoadRoundTrip()
    tests.loadReturnsNilWhenNoFile()
    tests.loadReturnsNilForCorruptedFile()
    tests.loadReturnsNilForWrongSchemaVersion()
    tests.saveCreatesFileWithCorrectKeys()
    tests.deleteRemovesFile()
    tests.deleteNoOpsWhenNoFile()
    tests.atomicWriteNoTempResidue()
}

func runActionPackOverrideMutationTests() {
    let tests = ActionPackOverrideMutationTests()
    tests.disablePackAddsId()
    tests.disablePackIdempotent()
    tests.disableAction()
    tests.disableActionUpdatesExistingOverride()
    tests.setDisplayName()
    tests.setDisplayNameUpdatesExistingOverride()
    tests.setTags()
    tests.setFrameDurations()
    tests.setSortOrder()
    tests.isPackDisabled()
    tests.isActionDisabled()
    tests.displayNameOverride()
    tests.sortOrderOverride()
    tests.disabledPackNotInCatalog()
    tests.disabledActionNotInCatalog()
    tests.displayNameOverrideApplied()
}

// MARK: - Store Tests

private struct ActionPackOverrideStoreTests {

    func saveAndLoadRoundTrip() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let overrides = ActionPackOverrideSet(
            petId: "test-pet",
            disabledPackIds: ["old_pack"],
            actionOverrides: [
                ActionPackActionOverride(
                    actionId: ActionId(rawValue: "wave_custom")!,
                    disabled: true,
                    displayName: "Old Wave",
                    tags: [ActionTag(rawValue: "vibe:cozy")!],
                    frameDurationsMs: [80, 120],
                    sortOrder: 5
                )
            ]
        )

        do {
            try store.save(overrides, petId: "test-pet")
            let loaded = store.load(petId: "test-pet")
            expect(loaded != nil, "loaded overrides should not be nil")
            expect(loaded?.petId == "test-pet", "petId should match")
            expect(loaded?.disabledPackIds == ["old_pack"], "disabled packs should match")
            expect(loaded?.actionOverrides.count == 1, "should have 1 action override")
            expect(loaded?.actionOverrides.first?.displayName == "Old Wave", "displayName should match")
            expect(loaded?.actionOverrides.first?.tags == [ActionTag(rawValue: "vibe:cozy")!], "tags should match")
            expect(loaded?.actionOverrides.first?.frameDurationsMs == [80, 120], "frame durations should match")
            expect(loaded?.actionOverrides.first?.sortOrder == 5, "sortOrder should match")
        } catch {
            fail("save and load should succeed; got \(error)")
        }
    }

    func loadReturnsNilWhenNoFile() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let result = store.load(petId: "nonexistent")
        expect(result == nil, "should return nil when no file exists")
    }

    func loadReturnsNilForCorruptedFile() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let petDir = tmpDir.appendingPathComponent("test-pet")
        try! FileManager.default.createDirectory(at: petDir, withIntermediateDirectories: true)
        try! Data("{ invalid json".utf8).write(to: petDir.appendingPathComponent(FileActionPackOverrideStore.fileName))

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let result = store.load(petId: "test-pet")
        expect(result == nil, "corrupted file should return nil")
    }

    func loadReturnsNilForWrongSchemaVersion() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let petDir = tmpDir.appendingPathComponent("test-pet")
        try! FileManager.default.createDirectory(at: petDir, withIntermediateDirectories: true)

        let json = """
        {
          "schemaVersion": 99,
          "petId": "test-pet",
          "disabledPackIds": [],
          "actionOverrides": []
        }
        """
        try! Data(json.utf8).write(to: petDir.appendingPathComponent(FileActionPackOverrideStore.fileName))

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let result = store.load(petId: "test-pet")
        expect(result == nil, "wrong schema version should return nil")
    }

    func saveCreatesFileWithCorrectKeys() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let overrides = ActionPackOverrideSet(petId: "test-pet")

        do {
            try store.save(overrides, petId: "test-pet")
            let url = tmpDir.appendingPathComponent("test-pet/\(FileActionPackOverrideStore.fileName)")
            expect(FileManager.default.fileExists(atPath: url.path), "file should exist")

            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            expect(json?["schemaVersion"] != nil, "should have schemaVersion key")
            expect(json?["petId"] as? String == "test-pet", "petId should match")
            expect(json?["disabledPackIds"] != nil, "should have disabledPackIds key")
            expect(json?["actionOverrides"] != nil, "should have actionOverrides key")
        } catch {
            fail("save should create file; got \(error)")
        }
    }

    func deleteRemovesFile() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let overrides = ActionPackOverrideSet(petId: "test-pet")
        try! store.save(overrides, petId: "test-pet")

        store.delete(petId: "test-pet")
        let result = store.load(petId: "test-pet")
        expect(result == nil, "after delete, load should return nil")
    }

    func deleteNoOpsWhenNoFile() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        store.delete(petId: "nonexistent")
        // Should not throw
    }

    func atomicWriteNoTempResidue() {
        let tmpDir = createTempDir()
        defer { cleanupTempDir(tmpDir) }

        let store = FileActionPackOverrideStore(petsDirectoryURL: tmpDir)
        let overrides = ActionPackOverrideSet(petId: "test-pet")
        try! store.save(overrides, petId: "test-pet")

        let petDir = tmpDir.appendingPathComponent("test-pet")
        let contents = try! FileManager.default.contentsOfDirectory(at: petDir, includingPropertiesForKeys: nil)
        let tmpFiles = contents.filter { $0.lastPathComponent.contains(".tmp-") }
        expect(tmpFiles.isEmpty, "no temp files should remain after successful save")
    }
}

// MARK: - Mutation Tests

private struct ActionPackOverrideMutationTests {

    private let waveId = ActionId(rawValue: "wave_custom")!
    private let sitId = ActionId(rawValue: "sit_custom")!

    func disablePackAddsId() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingPack("old_pack")
        expect(overrides.disabledPackIds == ["old_pack"], "should contain disabled pack")
    }

    func disablePackIdempotent() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingPack("old_pack")
            .disablingPack("old_pack")
        expect(overrides.disabledPackIds.count == 1, "should not duplicate pack id")
    }

    func disableAction() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingAction(waveId)
        expect(overrides.isActionDisabled(waveId), "action should be disabled")
    }

    func disableActionUpdatesExistingOverride() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("Custom Wave", for: waveId)
            .disablingAction(waveId)
        expect(overrides.isActionDisabled(waveId), "action should be disabled")
        expect(overrides.displayNameOverride(for: waveId) == "Custom Wave", "displayName should be preserved")
    }

    func setDisplayName() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("My Wave", for: waveId)
        expect(overrides.displayNameOverride(for: waveId) == "My Wave", "displayName should match")
    }

    func setDisplayNameUpdatesExistingOverride() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingAction(waveId)
            .settingDisplayName("New Name", for: waveId)
        expect(overrides.displayNameOverride(for: waveId) == "New Name", "displayName should be updated")
        expect(overrides.isActionDisabled(waveId), "disabled state should be preserved")
    }

    func setTags() {
        let tags = [ActionTag(rawValue: "vibe:cozy")!]
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("My Wave", for: waveId)
            .settingTags(tags, for: waveId)
        expect(overrides.tagsOverride(for: waveId) == tags, "tags should match")
        expect(overrides.displayNameOverride(for: waveId) == "My Wave", "displayName should be preserved")
    }

    func setFrameDurations() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("My Wave", for: waveId)
            .settingFrameDurations([90, 240], for: waveId)
        expect(overrides.frameDurationsOverride(for: waveId) == [90, 240], "frame durations should match")
        expect(overrides.displayNameOverride(for: waveId) == "My Wave", "displayName should be preserved")
    }

    func setSortOrder() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingSortOrder(10, for: waveId)
        expect(overrides.sortOrderOverride(for: waveId) == 10, "sortOrder should match")
    }

    func isPackDisabled() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingPack("disabled_pack")
        expect(overrides.isPackDisabled("disabled_pack"), "should be disabled")
        expect(!overrides.isPackDisabled("other_pack"), "other pack should not be disabled")
    }

    func isActionDisabled() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingAction(waveId)
        expect(overrides.isActionDisabled(waveId), "should be disabled")
        expect(!overrides.isActionDisabled(sitId), "other action should not be disabled")
    }

    func displayNameOverride() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
        expect(overrides.displayNameOverride(for: waveId) == nil, "should be nil when not set")
    }

    func sortOrderOverride() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
        expect(overrides.sortOrderOverride(for: waveId) == nil, "should be nil when not set")
    }

    func disabledPackNotInCatalog() {
        // Verifies that the override model correctly identifies disabled packs
        // The actual catalog filtering is tested in Module 3.5 (composer)
        let overrides = ActionPackOverrideSet(
            petId: "test-pet",
            disabledPackIds: ["broken_pack", "old_pack"]
        )
        expect(overrides.isPackDisabled("broken_pack"), "broken_pack should be disabled")
        expect(overrides.isPackDisabled("old_pack"), "old_pack should be disabled")
        expect(!overrides.isPackDisabled("good_pack"), "good_pack should not be disabled")
    }

    func disabledActionNotInCatalog() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .disablingAction(waveId)
        expect(overrides.isActionDisabled(waveId), "wave should be disabled")
        expect(!overrides.isActionDisabled(sitId), "sit should not be disabled")
    }

    func displayNameOverrideApplied() {
        let overrides = ActionPackOverrideSet(petId: "test-pet")
            .settingDisplayName("Custom Wave Name", for: waveId)
        expect(overrides.displayNameOverride(for: waveId) == "Custom Wave Name", "should return custom name")
    }
}

// MARK: - Temp Directory Helpers

private func createTempDir() -> URL {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("action-pack-override-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return tmpDir
}

private func cleanupTempDir(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
