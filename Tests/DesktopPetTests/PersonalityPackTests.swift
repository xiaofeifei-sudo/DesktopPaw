import Foundation
import DesktopPet

func runPersonalityPackTests() {
    let tests = PersonalityPackTests()
    tests.personalityPackBuildsSafeProfile()
    tests.personalityPackBuildsRuleBubbleCatalog()
    tests.enabledPersonalityProfilesExtendBaseProfiles()
    tests.disabledPersonalityPackDoesNotExtendProfiles()
}

private struct PersonalityPackTests {
    func personalityPackBuildsSafeProfile() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makePersonalityPackDirectory(root: root, id: "com.test.personality.decode")
        let manifest = try! ContentPackManifest.load(from: packURL)

        let pack = try! PersonalityPack.load(from: packURL, manifest: manifest)
        let profile = pack.profile()

        expect(profile.id == "com.test.personality.decode", "personality profile id should match pack id")
        expect(profile.name == "测试内容包", "profile should use manifest name")
        expect(profile.previewPhrases == ["轻轻陪你", "不打扰你"], "profile should use payload previews")
        expect(profile.responseMaxLength == 12, "personality pack should keep safe bubble length")
        expect(profile.canInitiativeBubble == false, "personality pack should not enable initiative bubbles")
    }

    func personalityPackBuildsRuleBubbleCatalog() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makePersonalityPackDirectory(root: root, id: "com.test.personality.bubble")
        let manifest = try! ContentPackManifest.load(from: packURL)

        let pack = try! PersonalityPack.load(from: packURL, manifest: manifest)
        let catalog = pack.bubbleCatalog()

        expect(catalog.phrases.map(\.text) == ["轻轻陪你", "不打扰你"],
               "personality pack previews should feed non-AI rule bubble candidates")
        expect(catalog.phrases.allSatisfy { $0.triggers == [.idle] },
               "personality rule bubbles should be ambient idle phrases")
    }

    func enabledPersonalityProfilesExtendBaseProfiles() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makePersonalityPackDirectory(root: sourceRoot, id: "com.test.personality.enabled"))
        try! manager.enablePack("com.test.personality.enabled")

        let profiles = manager.availablePersonalityProfiles(base: [.gentle])

        expect(profiles.contains(.gentle), "available profiles should keep built-in profile")
        expect(profiles.contains { $0.id == "com.test.personality.enabled" },
               "available profiles should include enabled personality pack")
    }

    func disabledPersonalityPackDoesNotExtendProfiles() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makePersonalityPackDirectory(root: sourceRoot, id: "com.test.personality.disabled"))

        let profiles = manager.availablePersonalityProfiles(base: [.gentle])

        expect(profiles == [.gentle], "disabled personality pack should not extend profiles")
    }
}
