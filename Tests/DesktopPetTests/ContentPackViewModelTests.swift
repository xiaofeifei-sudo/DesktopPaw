import Foundation
import DesktopPet

@MainActor
func runContentPackViewModelTests() {
    let tests = ContentPackViewModelTests()
    tests.importPackReloadsInstalledPacks()
    tests.enableDisableRemoveAndRestoreRefreshPackList()
    tests.previewPackStoresSelectedPreview()
}

@MainActor
private struct ContentPackViewModelTests {
    func importPackReloadsInstalledPacks() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        let model = ContentPackViewModel(manager: manager)

        model.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.vm.import"))

        expect(model.packs.map(\.id) == ["com.test.vm.import"],
               "importPack should reload installed pack list")
        expect(model.errorMessage == nil, "valid import should not set error")
    }

    func enableDisableRemoveAndRestoreRefreshPackList() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        let model = ContentPackViewModel(manager: manager)
        model.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.vm.toggle"))

        model.enablePack("com.test.vm.toggle")
        expect(model.packs.first?.isEnabled == true, "enablePack should refresh enabled state")

        model.disablePack("com.test.vm.toggle")
        expect(model.packs.first?.isEnabled == false, "disablePack should refresh enabled state")

        model.enablePack("com.test.vm.toggle")
        model.restoreDefaultContent()
        expect(model.packs.first?.isEnabled == false, "restoreDefaultContent should refresh disabled state")

        model.removePack("com.test.vm.toggle")
        expect(model.packs.isEmpty, "removePack should refresh pack list")
    }

    func previewPackStoresSelectedPreview() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        let model = ContentPackViewModel(manager: manager)
        model.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.vm.preview"))

        model.previewPack("com.test.vm.preview")

        expect(model.selectedPreview?.packId == "com.test.vm.preview",
               "previewPack should publish selected preview")
        expect(model.selectedPreview?.phrases.contains("新台词") == true,
               "preview should include pack content")
    }
}
