import Foundation
import DesktopPet

func runPetLibraryManifestWriterTests() {
    let tests = PetLibraryManifestWriterTests()
    tests.writesSchemaV2Manifest()
    tests.writesPetIdAndDisplayName()
    tests.writesSingleImageAssetKindAndAssets()
    tests.writesFrameSizeFromImportedImage()
    tests.writesSevenStateAnimationClips()
    tests.writesDefaultMotionProfile()
    tests.writesDefaultBubbleProfile()
    tests.writtenManifestRoundtripsToPetDefinition()
    tests.cleansUpFolderOnFailure()
    tests.cleanupSurvivesIndependentManifestRetry()
}

private struct PetLibraryManifestWriterTests {
    func writesSchemaV2Manifest() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let imported = makeImportedPetImage()

        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "momo-7f3a",
                displayName: "Momo",
                image: imported,
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(manifest.schemaVersion == 2, "schema version should be 2, got \(manifest.schemaVersion)")
    }

    func writesPetIdAndDisplayName() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let imported = makeImportedPetImage()

        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "luna-001",
                displayName: "Luna",
                image: imported,
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(manifest.id == "luna-001", "manifest id should match input, got \(manifest.id)")
        expect(manifest.displayName == "Luna", "manifest displayName should match input, got \(manifest.displayName)")
    }

    func writesSingleImageAssetKindAndAssets() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let imported = ImportedPetImage(
            imageFileName: "image.png",
            previewFileName: "preview.png",
            pixelSize: CGSizeCodable(width: 256, height: 256),
            hasAlpha: true
        )

        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-1",
                displayName: "Pet",
                image: imported,
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(manifest.assetKind == .singleImage, "asset kind should be singleImage, got \(manifest.assetKind)")
        expect(manifest.asset == "image.png", "asset filename should equal imported.imageFileName")
        expect(manifest.preview == "preview.png", "preview filename should equal imported.previewFileName")
        expect(manifest.spritesheet == nil, "single image manifest should not include a spritesheet layout")
    }

    func writesFrameSizeFromImportedImage() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let imported = ImportedPetImage(
            imageFileName: "image.png",
            previewFileName: "preview.png",
            pixelSize: CGSizeCodable(width: 320, height: 200),
            hasAlpha: false
        )

        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-2",
                displayName: "Pet",
                image: imported,
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(manifest.frameSize.width == 320, "frame size width should match imported pixel size, got \(manifest.frameSize.width)")
        expect(manifest.frameSize.height == 200, "frame size height should match imported pixel size, got \(manifest.frameSize.height)")
    }

    func writesSevenStateAnimationClips() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-3",
                displayName: "Pet",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(
            manifest.animations.count == PetState.allCases.count,
            "manifest should include seven animation clips, got \(manifest.animations.count)"
        )
        for state in PetState.allCases {
            guard let clip = manifest.animations[state] else {
                fail("missing animation clip for state \(state.rawValue)")
            }
            expect(!clip.frames.isEmpty, "animation \(state.rawValue) should have at least one frame")
        }
    }

    func writesDefaultMotionProfile() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-4",
                displayName: "Pet",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        guard let profile = manifest.motionProfile else {
            fail("motion profile should be written")
        }
        expect(
            profile.stateMotions.count == PetState.allCases.count,
            "default motion profile should cover seven states, got \(profile.stateMotions.count)"
        )
    }

    func writesDefaultBubbleProfile() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-5",
                displayName: "Pet",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        guard let profile = manifest.bubbleProfile else {
            fail("bubble profile should be written")
        }
        expect(profile.minimumIntervalSeconds > 0, "default bubble profile minimum interval should be positive")
        expect(profile.displayDurationSeconds > 0, "default bubble profile display duration should be positive")
        expect(!profile.phrases.isEmpty, "default bubble profile should provide phrases")
    }

    func writtenManifestRoundtripsToPetDefinition() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-6",
                displayName: "Pet",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("manifest writing should succeed: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        do {
            let definition = try manifest.petDefinition()
            expect(definition.assetKind == .singleImage, "definition should preserve singleImage asset kind")
            expect(
                definition.animations.count == PetState.allCases.count,
                "definition should expose seven animations, got \(definition.animations.count)"
            )
        } catch {
            fail("written manifest should produce a valid pet definition: \(error)")
        }
    }

    func cleansUpFolderOnFailure() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let imageURL = folder.appendingPathComponent("image.png")
        let previewURL = folder.appendingPathComponent("preview.png")
        do {
            try Data("dummy".utf8).write(to: imageURL)
            try Data("dummy".utf8).write(to: previewURL)
        } catch {
            fail("could not seed half-imported assets: \(error)")
        }

        // Force manifest write to fail by occupying manifest.json with a directory.
        let manifestPath = folder.appendingPathComponent("manifest.json", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: manifestPath, withIntermediateDirectories: true)
        } catch {
            fail("could not create blocking manifest directory: \(error)")
        }

        let imported = ImportedPetImage(
            imageFileName: "image.png",
            previewFileName: "preview.png",
            pixelSize: CGSizeCodable(width: 64, height: 64),
            hasAlpha: false
        )

        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-fail",
                displayName: "Fail",
                image: imported,
                to: folder
            )
            fail("manifest writing should fail when manifest path is occupied")
        } catch let error as PetLibraryError {
            expect(error == .cannotWriteManifest, "expected cannotWriteManifest, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }

        expect(
            !FileManager.default.fileExists(atPath: folder.path),
            "destination folder should be removed after a manifest write failure"
        )
    }

    func cleanupSurvivesIndependentManifestRetry() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let folder = scratch.makePetFolder()
        let writer = PetLibraryManifestWriter()
        do {
            try writer.writeSingleImageManifest(
                petId: "pet-retry-a",
                displayName: "First",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("first manifest writing should succeed: \(error)")
        }

        do {
            try writer.writeSingleImageManifest(
                petId: "pet-retry-b",
                displayName: "Second",
                image: makeImportedPetImage(),
                to: folder
            )
        } catch {
            fail("subsequent manifest write should overwrite without crashing: \(error)")
        }

        let manifest = decodeManifest(at: folder)
        expect(manifest.id == "pet-retry-b", "second write should replace previous manifest, got \(manifest.id)")
    }

    private func decodeManifest(at folder: URL) -> PetPackageManifest {
        let manifestURL = folder.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            fail("manifest.json should exist at \(manifestURL.path)")
        }

        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            fail("manifest.json should be readable: \(error)")
        }

        do {
            return try JSONDecoder().decode(PetPackageManifest.self, from: data)
        } catch {
            fail("manifest.json should decode as PetPackageManifest: \(error)")
        }
    }

    private func makeImportedPetImage() -> ImportedPetImage {
        ImportedPetImage(
            imageFileName: "image.png",
            previewFileName: "preview.png",
            pixelSize: CGSizeCodable(width: 512, height: 512),
            hasAlpha: true
        )
    }

    private func makeScratch() -> Scratch {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopPetManifestWriterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Scratch(root: root)
    }
}

private struct Scratch {
    let root: URL

    func makePetFolder(name: String = UUID().uuidString) -> URL {
        let folder = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
