import Foundation
import DesktopPet

func runDialoguePackTests() {
    let tests = DialoguePackTests()
    tests.dialoguePackDecodesToBubblePhraseCatalog()
    tests.enabledDialogueCatalogMergesWithBaseCatalog()
    tests.disabledDialoguePackDoesNotAffectCatalog()
}

private struct DialoguePackTests {
    func dialoguePackDecodesToBubblePhraseCatalog() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeDialoguePackDirectory(root: root, id: "com.test.dialogue.decode")
        let manifest = try! ContentPackManifest.load(from: packURL)

        let pack = try! DialoguePack.load(from: packURL, manifest: manifest)
        let catalog = pack.bubbleCatalog()

        expect(catalog.phrases.count == 1, "dialogue pack should create one phrase")
        expect(catalog.phrases[0].id == "com.test.dialogue.decode:hello",
               "dialogue phrase id should be namespaced by pack id")
        expect(catalog.phrases[0].matchesTrigger(.idle), "dialogue phrase should preserve trigger")
    }

    func enabledDialogueCatalogMergesWithBaseCatalog() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.dialogue.enabled"))
        try! manager.enablePack("com.test.dialogue.enabled")
        let base = BubblePhraseCatalog(phrases: [BubblePhrase(id: "base", text: "默认", triggers: [.idle])])

        let merged = manager.enabledDialogueCatalog(merging: base)

        expect(merged.phrase(withId: "base") != nil, "merged catalog should keep base phrase")
        expect(merged.phrase(withId: "com.test.dialogue.enabled:hello")?.text == "新台词",
               "merged catalog should include enabled dialogue phrase")
    }

    func disabledDialoguePackDoesNotAffectCatalog() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.dialogue.disabled"))
        let base = BubblePhraseCatalog(phrases: [BubblePhrase(id: "base", text: "默认", triggers: [.idle])])

        let merged = manager.enabledDialogueCatalog(merging: base)

        expect(merged.phrases == base.phrases, "disabled dialogue pack should not change catalog")
    }
}
