import Foundation
import ImageIO
@preconcurrency import AppKit
import DesktopPet

func runPetdexPackageImporterTests() {
    let tests = PetdexPackageImporterTests()
    tests.importsValidPetdexZip()
    tests.importTrimsTrailingTransparentPetdexFrames()
    tests.missingManifestFailsWithoutCreatingPetFolder()
    tests.missingSpritesheetFailsWithoutCreatingPetFolder()
    tests.invalidImageFailsWithoutCreatingPetFolder()
    tests.rejectsBuiltInPetIdConflict()
    tests.rejectsExistingImportedPetIdConflict()
    tests.writeFailureCleansUpPartialFolder()
    tests.failedImportDoesNotChangeCurrentPetValue()
}

private struct PetdexPackageImporterTests {
    func importsValidPetdexZip() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(
            entries: validEntries() + [
                .stored(name: "script.sh", data: Data("#!/bin/sh\necho should-not-run\n".utf8))
            ]
        )
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        let definition: PetDefinition
        do {
            definition = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        } catch {
            fail("valid Petdex zip should import successfully: \(error)")
        }

        expect(definition.id == "my-cat-v3-large", "importer should return converted definition")
        expect(definition.assetKind == .spriteSheet, "imported definition should be spriteSheet")
        expect(definition.catalog.actions.count == 9, "imported definition should include one generic action per Petdex row")
        expect(definition.catalog.actions.allSatisfy { $0.role == nil }, "imported Petdex actions should not be forced into legacy states")

        let petFolder = petsRoot.appendingPathComponent("my-cat-v3-large", isDirectory: true)
        expect(FileManager.default.fileExists(atPath: petFolder.path), "import should create App-owned pet folder")
        expect(FileManager.default.fileExists(atPath: petFolder.appendingPathComponent("manifest.json").path), "manifest.json should be written")
        expect(FileManager.default.fileExists(atPath: petFolder.appendingPathComponent("spritesheet.png").path), "spritesheet.png should be written")
        expect(FileManager.default.fileExists(atPath: petFolder.appendingPathComponent("preview.png").path), "preview.png should be written")
        expect(FileManager.default.fileExists(atPath: petFolder.appendingPathComponent("petdex-source.json").path), "petdex-source.json should be written")
        expect(!FileManager.default.fileExists(atPath: petFolder.appendingPathComponent("script.sh").path), "extra zip files should not be copied")

        do {
            try FileManager.default.removeItem(at: archiveURL)
        } catch {
            fail("could not remove original zip fixture: \(error)")
        }

        let manifestURL = petFolder.appendingPathComponent("manifest.json")
        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PetPackageManifest.self, from: data)
            let loadedDefinition = try manifest.petDefinition()
            expect(loadedDefinition.id == definition.id, "imported pet should load after original zip is deleted")
        } catch {
            fail("imported manifest should remain valid after original zip deletion: \(error)")
        }

        expect(NSImage(contentsOf: petFolder.appendingPathComponent("spritesheet.png")) != nil, "spritesheet.png should be loadable")
        expect(NSImage(contentsOf: petFolder.appendingPathComponent("preview.png")) != nil, "preview.png should be loadable")
    }

    func importTrimsTrailingTransparentPetdexFrames() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(
            spritesheetData: makeSparsePNGData(
                columns: 8,
                rows: 9,
                frameWidth: 2,
                frameHeight: 2,
                visibleColumnsByRow: [
                    0: 6,
                    1: 8,
                    2: 8,
                    3: 4,
                    4: 5,
                    5: 8,
                    6: 6,
                    7: 6,
                    8: 6
                ]
            )
        ))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        do {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        } catch {
            fail("sparse Petdex zip should import successfully: \(error)")
        }

        let manifestURL = petsRoot
            .appendingPathComponent("my-cat-v3-large", isDirectory: true)
            .appendingPathComponent("manifest.json")

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PetPackageManifest.self, from: data)
            let action1 = manifest.actions.first { $0.id == ActionId(rawValue: "action_1")! }
            let action4 = manifest.actions.first { $0.id == ActionId(rawValue: "action_4")! }
            let action8 = manifest.actions.first { $0.id == ActionId(rawValue: "action_8")! }

            expect(action1?.frames.count == 6, "action_1 should trim trailing transparent Petdex frames")
            expect(action4?.frames.count == 4, "action_4 should trim to its last visible frame")
            expect(action8?.frames.count == 6, "generic Petdex rows should also trim trailing transparent frames")
        } catch {
            fail("trimmed imported manifest should decode: \(error)")
        }
    }

    func missingManifestFailsWithoutCreatingPetFolder() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: [
            .stored(name: "spritesheet.png", data: makePNGData(width: 16, height: 18))
        ])
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        expectPetdexError(.missingManifest) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }
        expect(!FileManager.default.fileExists(atPath: petsRoot.path), "missing manifest should fail before creating pet root")
    }

    func missingSpritesheetFailsWithoutCreatingPetFolder() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: [
            .stored(name: "pet.json", data: validManifestData())
        ])
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        expectPetdexError(.missingSpritesheet("spritesheet.png")) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }
        expect(!FileManager.default.fileExists(atPath: petsRoot.path), "missing spritesheet should fail before creating pet root")
    }

    func invalidImageFailsWithoutCreatingPetFolder() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: [
            .stored(name: "pet.json", data: validManifestData()),
            .stored(name: "spritesheet.png", data: Data("not an image".utf8))
        ])
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        expectPetdexError(.unreadableImage("spritesheet.png")) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }
        expect(!FileManager.default.fileExists(atPath: petsRoot.path), "invalid image should fail before creating pet root")
    }

    func rejectsBuiltInPetIdConflict() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "starter-pet"))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        expectPetdexError(.petAlreadyExists("starter-pet")) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }
        expect(!FileManager.default.fileExists(atPath: petsRoot.path), "built-in id conflict should not create pet root")
    }

    func rejectsExistingImportedPetIdConflict() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "dupe-pet"))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let existingFolder = petsRoot.appendingPathComponent("dupe-pet", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: existingFolder, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: existingFolder.appendingPathComponent("marker.txt"))
        } catch {
            fail("could not seed existing pet folder: \(error)")
        }

        expectPetdexError(.petAlreadyExists("dupe-pet")) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }

        expect(FileManager.default.fileExists(atPath: existingFolder.appendingPathComponent("marker.txt").path), "existing pet folder should not be removed on conflict")
    }

    func writeFailureCleansUpPartialFolder() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "write-fails"))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let importer = PetdexPackageImporter(fileWriter: { _, _ in
            throw NSError(domain: "PetdexPackageImporterTests", code: 1)
        })

        expectWriteFailed {
            _ = try importer.importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }

        let destination = petsRoot.appendingPathComponent("write-fails", isDirectory: true)
        expect(!FileManager.default.fileExists(atPath: destination.path), "write failure should clean up partial pet folder")
    }

    func failedImportDoesNotChangeCurrentPetValue() {
        let scratch = PetdexImporterScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: [
            .stored(name: "pet.json", data: validManifestData())
        ])
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let currentPetId = "starter-pet"

        expectPetdexError(.missingSpritesheet("spritesheet.png")) {
            _ = try PetdexPackageImporter().importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }

        expect(currentPetId == "starter-pet", "failed import should not modify caller-owned current pet state")
    }

    private func validEntries(
        id: String = "my-cat-v3-large",
        spritesheetData: Data? = nil
    ) -> [PetdexZipEntry] {
        [
            .stored(name: "pet.json", data: validManifestData(id: id)),
            .stored(name: "spritesheet.png", data: spritesheetData ?? makePNGData(width: 16, height: 18))
        ]
    }

    private func validManifestData(id: String = "my-cat-v3-large") -> Data {
        Data(
            """
            {
              "id": "\(id)",
              "displayName": "Beibei",
              "description": "A Petdex cat package.",
              "spritesheetPath": "spritesheet.png"
            }
            """.utf8
        )
    }

    private func makePNGData(width: Int, height: Int) -> Data {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fail("could not create PNG context")
        }

        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            fail("could not create PNG image")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            fail("could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fail("could not encode PNG")
        }
        return output as Data
    }

    private func makeSparsePNGData(
        columns: Int,
        rows: Int,
        frameWidth: Int,
        frameHeight: Int,
        visibleColumnsByRow: [Int: Int]
    ) -> Data {
        let width = columns * frameWidth
        let height = rows * frameHeight
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<rows {
            let visibleColumns = min(max(visibleColumnsByRow[row] ?? columns, 1), columns)
            for column in 0..<visibleColumns {
                for y in (row * frameHeight)..<((row + 1) * frameHeight) {
                    for x in (column * frameWidth)..<((column + 1) * frameWidth) {
                        let offset = (y * width + x) * 4
                        pixels[offset] = 200
                        pixels[offset + 1] = 25
                        pixels[offset + 2] = 50
                        pixels[offset + 3] = 255
                    }
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            fail("could not create sparse PNG image")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            fail("could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fail("could not encode PNG")
        }
        return output as Data
    }

    private func expectPetdexError(
        _ expected: PetdexImportError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            fail("expected Petdex error \(expected)")
        } catch let error as PetdexImportError {
            expect(error == expected, "expected \(expected), got \(error)")
        } catch {
            fail("expected PetdexImportError \(expected), got \(error)")
        }
    }

    private func expectWriteFailed(operation: () throws -> Void) {
        do {
            try operation()
            fail("expected writeFailed error")
        } catch PetdexImportError.writeFailed {
        } catch {
            fail("expected writeFailed, got \(error)")
        }
    }
}

private struct PetdexImporterScratch {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetdexImporterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeZip(entries: [PetdexZipEntry]) -> URL {
        let url = root.appendingPathComponent("petdex.zip")
        do {
            try makeZipData(entries: entries).write(to: url)
        } catch {
            fail("could not write Petdex zip fixture: \(error)")
        }
        return url
    }

    private func makeZipData(entries: [PetdexZipEntry]) -> Data {
        var localData = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localHeaderOffset = localData.count
            let nameData = Data(entry.name.utf8)

            localData.appendPetdexZipUInt32(0x0403_4B50)
            localData.appendPetdexZipUInt16(20)
            localData.appendPetdexZipUInt16(0)
            localData.appendPetdexZipUInt16(0)
            localData.appendPetdexZipUInt16(0)
            localData.appendPetdexZipUInt16(0)
            localData.appendPetdexZipUInt32(0)
            localData.appendPetdexZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexZipUInt16(UInt16(nameData.count))
            localData.appendPetdexZipUInt16(0)
            localData.append(nameData)
            localData.append(entry.data)

            centralDirectory.appendPetdexZipUInt32(0x0201_4B50)
            centralDirectory.appendPetdexZipUInt16(20)
            centralDirectory.appendPetdexZipUInt16(20)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt32(0)
            centralDirectory.appendPetdexZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexZipUInt16(UInt16(nameData.count))
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt16(0)
            centralDirectory.appendPetdexZipUInt32(0)
            centralDirectory.appendPetdexZipUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = localData.count
        localData.append(centralDirectory)
        localData.appendPetdexZipUInt32(0x0605_4B50)
        localData.appendPetdexZipUInt16(0)
        localData.appendPetdexZipUInt16(0)
        localData.appendPetdexZipUInt16(UInt16(entries.count))
        localData.appendPetdexZipUInt16(UInt16(entries.count))
        localData.appendPetdexZipUInt32(UInt32(centralDirectory.count))
        localData.appendPetdexZipUInt32(UInt32(centralDirectoryOffset))
        localData.appendPetdexZipUInt16(0)

        return localData
    }
}

private struct PetdexZipEntry {
    let name: String
    let data: Data

    static func stored(name: String, data: Data) -> PetdexZipEntry {
        PetdexZipEntry(name: name, data: data)
    }
}

private extension Data {
    mutating func appendPetdexZipUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendPetdexZipUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}
