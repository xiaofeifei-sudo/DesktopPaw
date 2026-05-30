import AppKit
import Foundation
import DesktopPet

func runPetPackageLoaderTests() {
    let tests = PetPackageLoaderTests()
    tests.loadsValidPetFolderWithMultiFrameAnimations()
    tests.rejectsNonPetFolder()
    tests.rejectsMissingManifest()
    tests.rejectsSingleImagePackage()
    tests.rejectsMissingAsset()
    tests.rejectsUnsafeAssetName()
    tests.rejectsUnreadableAsset()
}

private struct PetPackageLoaderTests {
    func loadsValidPetFolderWithMultiFrameAnimations() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let packageURL = scratch.makePackage(id: "runner-pet", includePreview: true)
        let loader = PetPackageLoader()

        do {
            let definition = try loader.loadPackage(at: packageURL)
            expect(definition.id == "runner-pet", "package loader should return manifest id")
            expect(definition.assetKind == .spriteSheet, "complete package should be spriteSheet")
            expect(definition.animation(for: .walking)?.frames.count == 2, "loader should preserve multi-frame clips")
            expect(definition.previewAssetName == "preview.png", "loader should preserve preview resource")
        } catch {
            fail("valid .pet package should load: \(error)")
        }
    }

    func rejectsNonPetFolder() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let folder = scratch.root.appendingPathComponent("NotAPackage", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        do {
            _ = try PetPackageLoader().loadPackage(at: folder)
            fail("non-.pet folder should be rejected")
        } catch PetAssetError.invalidPackageExtension {
        } catch {
            fail("expected invalidPackageExtension, got \(error)")
        }
    }

    func rejectsMissingManifest() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.root.appendingPathComponent("Empty.pet", isDirectory: true)
        try? FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)

        do {
            _ = try PetPackageLoader().loadPackage(at: package)
            fail("package without manifest should fail")
        } catch PetAssetError.manifestNotFound {
        } catch {
            fail("expected manifestNotFound, got \(error)")
        }
    }

    func rejectsSingleImagePackage() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "single", assetKind: "singleImage", spritesheet: nil)

        do {
            _ = try PetPackageLoader().loadPackage(at: package)
            fail("singleImage package should be imported through image flow, not package flow")
        } catch PetAssetError.singleImagePackageUnsupported {
        } catch {
            fail("expected singleImagePackageUnsupported, got \(error)")
        }
    }

    func rejectsMissingAsset() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "missing-asset", writeAsset: false)

        do {
            _ = try PetPackageLoader().loadPackage(at: package)
            fail("package missing asset should fail")
        } catch PetAssetError.missingPackageResource(let name) {
            expect(name == "spritesheet.png", "missing resource should name spritesheet.png")
        } catch {
            fail("expected missingPackageResource, got \(error)")
        }
    }

    func rejectsUnsafeAssetName() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "unsafe", assetName: "../spritesheet.png")

        do {
            _ = try PetPackageLoader().loadPackage(at: package)
            fail("unsafe asset path should fail")
        } catch PetAssetError.unsafePackageResourceName(let name) {
            expect(name == "../spritesheet.png", "unsafe resource error should preserve name")
        } catch {
            fail("expected unsafePackageResourceName, got \(error)")
        }
    }

    func rejectsUnreadableAsset() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "unreadable", writeAsset: false)
        let badAsset = package.appendingPathComponent("spritesheet.png")
        try? Data("not an image".utf8).write(to: badAsset)

        do {
            _ = try PetPackageLoader().loadPackage(at: package)
            fail("unreadable asset should fail")
        } catch PetAssetError.unreadablePackageResource(let name) {
            expect(name == "spritesheet.png", "unreadable resource should name spritesheet.png")
        } catch {
            fail("expected unreadablePackageResource, got \(error)")
        }
    }
}

func runPetPackageImporterTests() {
    let tests = PetPackageImporterTests()
    tests.importCopiesManifestSpritesheetAndPreviewOnly()
    tests.rejectsDuplicatePackageId()
    tests.mapsMissingPackageResourceToLibraryError()
}

private struct PetPackageImporterTests {
    func importCopiesManifestSpritesheetAndPreviewOnly() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "package-pet", includePreview: true)
        try? Data("#!/bin/sh\necho no\n".utf8).write(to: package.appendingPathComponent("script.sh"))
        let destinationRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        do {
            let definition = try PetPackageImporter().importPackage(
                from: package,
                to: destinationRoot,
                builtInPetId: "starter-pet"
            )
            expect(definition.id == "package-pet", "importer should return loaded package definition")
        } catch {
            fail("valid package import should succeed: \(error)")
        }

        let imported = destinationRoot.appendingPathComponent("package-pet", isDirectory: true)
        expect(FileManager.default.fileExists(atPath: imported.appendingPathComponent("manifest.json").path), "manifest should be copied")
        expect(FileManager.default.fileExists(atPath: imported.appendingPathComponent("spritesheet.png").path), "spritesheet should be copied")
        expect(FileManager.default.fileExists(atPath: imported.appendingPathComponent("preview.png").path), "preview should be copied")
        expect(!FileManager.default.fileExists(atPath: imported.appendingPathComponent("script.sh").path), "extra package scripts should not be copied")
    }

    func rejectsDuplicatePackageId() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "dupe-pet")
        let destinationRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let importer = PetPackageImporter()

        do {
            _ = try importer.importPackage(from: package, to: destinationRoot, builtInPetId: "starter-pet")
        } catch {
            fail("first import should succeed: \(error)")
        }

        do {
            _ = try importer.importPackage(from: package, to: destinationRoot, builtInPetId: "starter-pet")
            fail("duplicate package id should fail")
        } catch let error as PetLibraryError {
            expect(error == .petAlreadyExists, "expected petAlreadyExists, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }

    func mapsMissingPackageResourceToLibraryError() {
        let scratch = PetPackageScratch()
        defer { scratch.cleanUp() }
        let package = scratch.makePackage(id: "missing", writeAsset: false)

        do {
            _ = try PetPackageImporter().importPackage(
                from: package,
                to: scratch.root.appendingPathComponent("Pets", isDirectory: true),
                builtInPetId: "starter-pet"
            )
            fail("missing package resource should fail")
        } catch let error as PetLibraryError {
            expect(error == .missingPackageResource, "expected missingPackageResource, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }
}

private final class PetPackageScratch {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetPackageTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func makePackage(
        id: String,
        assetName: String = "spritesheet.png",
        includePreview: Bool = true,
        writeAsset: Bool = true,
        assetKind: String = "spriteSheet",
        spritesheet: String? = #""spritesheet": { "columns": 2, "rows": 7 }"#
    ) -> URL {
        let package = root.appendingPathComponent("\(id).pet", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            let previewLine = includePreview ? #""preview": "preview.png","# : ""
            let spriteLine = spritesheet.map { "\($0)," } ?? ""
            let json = packageManifestJSON(
                id: id,
                assetName: assetName,
                previewLine: previewLine,
                assetKind: assetKind,
                spritesheetLine: spriteLine
            )
            try Data(json.utf8).write(to: package.appendingPathComponent("manifest.json"))
            if writeAsset && !assetName.contains("/") && !assetName.contains("\\") {
                try makePNGData(width: 256, height: 896).write(to: package.appendingPathComponent(assetName))
            }
            if includePreview {
                try makePNGData(width: 128, height: 128).write(to: package.appendingPathComponent("preview.png"))
            }
        } catch {
            fail("failed to create package fixture: \(error)")
        }
        return package
    }
}

private func packageManifestJSON(
    id: String,
    assetName: String,
    previewLine: String,
    assetKind: String,
    spritesheetLine: String
) -> String {
    """
    {
      "schemaVersion": 2,
      "id": "\(id)",
      "displayName": "\(id)",
      "description": "package fixture",
      "asset": "\(assetName)",
      \(previewLine)
      "assetKind": "\(assetKind)",
      "frameSize": { "width": 128, "height": 128 },
      \(spritesheetLine)
      "defaultScale": 1.0,
      "animations": {
        "idle": { "frames": [{ "column": 0, "row": 0 }, { "column": 1, "row": 0 }], "frameDurationMs": 160, "loop": true },
        "walking": { "frames": [{ "column": 0, "row": 1 }, { "column": 1, "row": 1 }], "frameDurationMs": 140, "loop": true },
        "sleeping": { "frames": [{ "column": 0, "row": 2 }], "frameDurationMs": 300, "loop": true },
        "happy": { "frames": [{ "column": 0, "row": 3 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "eating": { "frames": [{ "column": 0, "row": 4 }], "frameDurationMs": 120, "loop": false, "nextState": "idle" },
        "jumping": { "frames": [{ "column": 0, "row": 5 }], "frameDurationMs": 110, "loop": false, "nextState": "idle" },
        "dragging": { "frames": [{ "column": 0, "row": 6 }], "frameDurationMs": 160, "loop": true }
      }
    }
    """
}

private func makePNGData(width: Int, height: Int) -> Data {
    let image = NSImage(size: CGSize(width: width, height: height))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fail("failed to create package PNG data")
    }
    return data
}
