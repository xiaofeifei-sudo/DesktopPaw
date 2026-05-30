import Foundation
import DesktopPet

func runActionPackTests() {
    let tests = ActionPackTests()
    tests.actionPackDecodesActions()
    tests.enabledActionCatalogMergesWithBaseCatalog()
    tests.actionPackDoesNotOverrideExistingActionIds()
}

private struct ActionPackTests {
    func actionPackDecodesActions() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeActionPackDirectory(root: root, id: "com.test.action.decode")
        let manifest = try! ContentPackManifest.load(from: packURL)

        let pack = try! ActionPack.load(from: packURL, manifest: manifest)

        expect(pack.actions.count == 1, "action pack should decode one action")
        expect(pack.actions[0].id.rawValue == "wave_extra", "action id should decode")
        expect(pack.actions[0].tags == [ActionTag(rawValue: "greeting")!], "action tags should decode")
    }

    func enabledActionCatalogMergesWithBaseCatalog() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makeActionPackDirectory(root: sourceRoot, id: "com.test.action.enabled"))
        try! manager.enablePack("com.test.action.enabled")
        let base = makeStandardCatalog()

        let merged = manager.enabledActionCatalog(merging: base)

        expect(merged.resolve(actionId: ActionId(rawValue: "idle_default")!) != nil,
               "merged action catalog should keep base action")
        expect(merged.resolve(actionId: ActionId(rawValue: "wave_extra")!) != nil,
               "merged action catalog should include enabled action")
    }

    func actionPackDoesNotOverrideExistingActionIds() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let duplicateURL = makeContentPackDirectory(
            root: sourceRoot,
            id: "com.test.action.duplicate",
            type: .action,
            contentFileName: "actions.json",
            contentJSON: """
            [
              {
                "id": "idle_default",
                "displayName": "不应覆盖",
                "role": "idle",
                "tags": [],
                "frames": [{ "column": 0, "row": 0 }],
                "frameDurationMs": 120,
                "loop": true,
                "nextActionId": null
              }
            ]
            """
        )
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: duplicateURL)
        try! manager.enablePack("com.test.action.duplicate")
        let base = makeStandardCatalog()

        let merged = manager.enabledActionCatalog(merging: base)

        expect(merged.resolve(actionId: ActionId(rawValue: "idle_default")!)?.displayName == "idle_default",
               "action pack should not override existing action ids")
    }
}
