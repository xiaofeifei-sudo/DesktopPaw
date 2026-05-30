import Foundation
import DesktopPet

func runContentPackManagerTests() {
    let tests = ContentPackManagerTests()
    tests.importPackInstallsDisabledPack()
    tests.enableDisableAndRemovePack()
    tests.restoreDefaultContentDisablesInstalledPacks()
    tests.previewPackReturnsTypeSpecificContent()
    tests.importInvalidPackThrowsValidationError()
}

private struct ContentPackManagerTests {
    func importPackInstallsDisabledPack() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let packURL = makeDialoguePackDirectory(root: sourceRoot, id: "com.test.import")
        let manager = ContentPackManager(installedRootURL: root)

        let pack = try! manager.importPack(from: packURL)
        let installed = manager.getInstalledPacks()

        expect(pack.id == "com.test.import", "import should return installed pack id")
        expect(!pack.isEnabled, "imported pack should start disabled")
        expect(installed.count == 1, "installed pack list should include imported pack")
        expect(installed[0].id == pack.id, "installed pack id should match import result")
    }

    func enableDisableAndRemovePack() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let packURL = makeDialoguePackDirectory(root: sourceRoot, id: "com.test.toggle")
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: packURL)

        try! manager.enablePack("com.test.toggle")
        expect(manager.getInstalledPacks()[0].isEnabled, "enablePack should mark pack enabled")

        try! manager.disablePack("com.test.toggle")
        expect(!manager.getInstalledPacks()[0].isEnabled, "disablePack should mark pack disabled")

        try! manager.removePack("com.test.toggle")
        expect(manager.getInstalledPacks().isEmpty, "removePack should delete installed pack")
    }

    func restoreDefaultContentDisablesInstalledPacks() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.a"))
        _ = try! manager.importPack(from: makePersonalityPackDirectory(root: sourceRoot, id: "com.test.b"))
        try! manager.enablePack("com.test.a")
        try! manager.enablePack("com.test.b")

        try! manager.restoreDefaultContent()

        expect(manager.getInstalledPacks().allSatisfy { !$0.isEnabled },
               "restoreDefaultContent should disable all installed packs")
    }

    func previewPackReturnsTypeSpecificContent() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let manager = ContentPackManager(installedRootURL: root)
        _ = try! manager.importPack(from: makeDialoguePackDirectory(root: sourceRoot, id: "com.test.preview"))

        let preview = try! manager.previewPack("com.test.preview")

        expect(preview.packId == "com.test.preview", "preview should include pack id")
        expect(preview.type == .dialogue, "preview should preserve pack type")
        expect(preview.phrases.contains("新台词"), "preview should include dialogue phrase text")
    }

    func importInvalidPackThrowsValidationError() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceRoot = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: sourceRoot) }
        let packURL = sourceRoot.appendingPathComponent("bad.dpcp", isDirectory: true)
        try! FileManager.default.createDirectory(at: packURL, withIntermediateDirectories: true)
        let manager = ContentPackManager(installedRootURL: root)

        do {
            _ = try manager.importPack(from: packURL)
            fail("importing invalid pack should throw")
        } catch let error as ContentPackError {
            if case .validationFailed = error {
            } else {
                fail("expected validationFailed, got \(error)")
            }
        } catch {
            fail("expected ContentPackError, got \(error)")
        }
    }
}
