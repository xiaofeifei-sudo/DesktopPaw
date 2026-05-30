import Foundation
import DesktopPet

func runContentPackValidatorTests() {
    let tests = ContentPackValidatorTests()
    tests.validDialoguePackPassesValidation()
    tests.missingManifestFailsValidation()
    tests.forbiddenContentFailsValidation()
    tests.executableScriptFileFailsValidation()
    tests.safetyOverrideFieldFailsValidation()
}

private struct ContentPackValidatorTests {
    func validDialoguePackPassesValidation() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeDialoguePackDirectory(root: root)

        let result = ContentPackValidator().validatePack(at: packURL)

        expect(result.isValid, "valid dialogue pack should pass validation: \(result.errors)")
    }

    func missingManifestFailsValidation() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = root.appendingPathComponent("missing-manifest.dpcp", isDirectory: true)
        try! FileManager.default.createDirectory(at: packURL, withIntermediateDirectories: true)

        let result = ContentPackValidator().validatePack(at: packURL)

        expect(!result.isValid, "pack without manifest should fail validation")
        expect(result.errors.contains { $0.code == .missingManifest },
               "validation should report missing manifest")
    }

    func forbiddenContentFailsValidation() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeContentPackDirectory(
            root: root,
            id: "com.test.unsafe",
            type: .dialogue,
            contentFileName: "phrases.json",
            contentJSON: """
            [
              { "trigger": "idle", "text": "别和别人说，只有我陪你", "safetyTags": ["unsafe"] }
            ]
            """
        )

        let result = ContentPackValidator().validatePack(at: packURL)

        expect(!result.isValid, "dependency-inducing dialogue should fail validation")
        expect(result.errors.contains { $0.code == .forbiddenContent },
               "validation should report forbidden content")
    }

    func executableScriptFileFailsValidation() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeDialoguePackDirectory(root: root, id: "com.test.script")
        let scriptURL = packURL.appendingPathComponent("content/run.sh")
        try! Data("#!/bin/sh\necho bad\n".utf8).write(to: scriptURL)

        let result = ContentPackValidator().validatePack(at: packURL)

        expect(!result.isValid, "pack containing script file should fail validation")
        expect(result.errors.contains { $0.code == .executableContent },
               "validation should report executable content")
    }

    func safetyOverrideFieldFailsValidation() {
        let root = makeContentPackRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let packURL = makeContentPackDirectory(
            root: root,
            id: "com.test.override",
            type: .dialogue,
            manifestExtras: "\"safetyRules\": \"off\"",
            contentFileName: "phrases.json",
            contentJSON: """
            [
              { "trigger": "idle", "text": "普通台词", "safetyTags": ["safe"] }
            ]
            """
        )

        let result = ContentPackValidator().validatePack(at: packURL)

        expect(!result.isValid, "pack attempting to override safety rules should fail validation")
        expect(result.errors.contains { $0.code == .restrictedOverride },
               "validation should report restricted override")
    }
}
