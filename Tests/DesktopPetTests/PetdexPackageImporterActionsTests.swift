import Foundation
import ImageIO
import DesktopPet

func runPetdexPackageImporterActionsTests() {
    let tests = PetdexPackageImporterActionsTests()
    tests.eightByNineZipImportsManifestWithNineActions()
    tests.sixByNineZipImportsNineGenericActions()
    tests.zeroRowsZipFailsWithoutChangingCurrentPet()
    tests.sixRowsZipImportsSixGenericActions()
    tests.writeFailureCleansUpPartialFolder()
}

private struct PetdexPackageImporterActionsTests {
    func eightByNineZipImportsManifestWithNineActions() {
        let scratch = PetdexImporterActionsScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "actions-8x9", columns: 8, rows: 9))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        do {
            _ = try makeImporter(columns: 8, rows: 9).importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        } catch {
            fail("8x9 Petdex zip should import through actions path: \(error)")
        }

        let manifest = readManifest(id: "actions-8x9", petsRoot: petsRoot)
        expect(manifest.schemaVersion == 2, "imported manifest should be schemaVersion=2")
        expect(manifest.actions.count == 9, "8x9 Petdex import should produce 9 actions")
        expect(manifest.actions.allSatisfy { $0.role == nil }, "8x9 Petdex import should keep actions role-less")
        expect(
            manifest.actions.map(\.id.rawValue) == (1...9).map { "action_\($0)" },
            "8x9 import should keep generic row action order"
        )
    }

    func sixByNineZipImportsNineGenericActions() {
        let scratch = PetdexImporterActionsScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "actions-6x9", columns: 6, rows: 9))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        do {
            _ = try makeImporter(columns: 6, rows: 9).importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        } catch {
            fail("6x9 Petdex zip should import with warning sidecar: \(error)")
        }

        let manifest = readManifest(id: "actions-6x9", petsRoot: petsRoot)
        expect(manifest.actions.count == 9, "6x9 Petdex import should keep every Petdex row as a generic action")
        expect(manifest.actions.allSatisfy { $0.role == nil }, "6x9 Petdex import should not assign legacy roles")
        expect(readWarningsIfPresent(id: "actions-6x9", petsRoot: petsRoot) == nil, "generic Petdex row mapping should not warn about extra rows")
    }

    func zeroRowsZipFailsWithoutChangingCurrentPet() {
        let scratch = PetdexImporterActionsScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "actions-0rows", columns: 8, rows: 1))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let currentPetId = "starter-pet"

        expectInvalidSpritesheetLayout {
            _ = try makeImporter(columns: 8, rows: 0).importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }

        expect(currentPetId == "starter-pet", "0-row import should not modify caller-owned current pet state")
        expect(!FileManager.default.fileExists(atPath: petsRoot.path), "0-row import should fail before creating pet root")
    }

    func sixRowsZipImportsSixGenericActions() {
        let scratch = PetdexImporterActionsScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "actions-6rows", columns: 8, rows: 6))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)

        do {
            _ = try makeImporter(columns: 8, rows: 6).importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        } catch {
            fail("6-row Petdex zip should import as generic actions: \(error)")
        }

        let manifest = readManifest(id: "actions-6rows", petsRoot: petsRoot)
        expect(manifest.actions.count == 6, "6-row Petdex import should keep exactly six generic actions")
        expect(manifest.actions.map(\.id.rawValue) == (1...6).map { "action_\($0)" }, "6-row import should keep row action order")
        expect(manifest.actions.allSatisfy { $0.role == nil }, "6-row import should not synthesize legacy roles")
        expect(readWarningsIfPresent(id: "actions-6rows", petsRoot: petsRoot) == nil, "6-row generic import should not warn about synthesized roles")
    }

    func writeFailureCleansUpPartialFolder() {
        let scratch = PetdexImporterActionsScratch()
        defer { scratch.cleanUp() }

        let archiveURL = scratch.writeZip(entries: validEntries(id: "actions-write-fails", columns: 8, rows: 9))
        let petsRoot = scratch.root.appendingPathComponent("Pets", isDirectory: true)
        let importer = makeImporter(columns: 8, rows: 9, fileWriter: { _, _ in
            throw NSError(domain: "PetdexPackageImporterActionsTests", code: 1)
        })

        expectWriteFailed {
            _ = try importer.importPackage(
                at: archiveURL,
                to: petsRoot,
                builtInPetId: "starter-pet"
            )
        }

        let destination = petsRoot.appendingPathComponent("actions-write-fails", isDirectory: true)
        expect(!FileManager.default.fileExists(atPath: destination.path), "write failure should clean up partial pet folder")
    }

    private func makeImporter(
        columns: Int,
        rows: Int,
        fileWriter: @escaping PetdexPackageImporter.FileWriter = { data, url in
            try data.write(to: url, options: [.atomic])
        }
    ) -> PetdexPackageImporter {
        PetdexPackageImporter(
            mappingProvider: DefaultPetdexAnimationMappingProvider(columns: columns, rows: rows),
            imageConvention: PetdexSpriteSheetConvention(columns: columns, rows: rows),
            fileWriter: fileWriter
        )
    }

    private func validEntries(id: String, columns: Int, rows: Int) -> [PetdexImporterActionsZipEntry] {
        [
            .stored(name: "pet.json", data: validManifestData(id: id)),
            .stored(name: "spritesheet.png", data: makePNGData(width: max(columns, 1) * 2, height: max(rows, 1) * 2))
        ]
    }

    private func validManifestData(id: String) -> Data {
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

    private func readManifest(id: String, petsRoot: URL) -> PetPackageManifest {
        let url = petsRoot
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(ConvertedPetPackage.manifestFileName)

        do {
            return try JSONDecoder().decode(PetPackageManifest.self, from: Data(contentsOf: url))
        } catch {
            fail("imported manifest should decode: \(error)")
        }
    }

    private func readWarnings(id: String, petsRoot: URL) -> [PetdexImporterWarningSidecarEntry] {
        let url = petsRoot
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)

        do {
            return try JSONDecoder().decode([PetdexImporterWarningSidecarEntry].self, from: Data(contentsOf: url))
        } catch {
            fail("import warning sidecar should decode: \(error)")
        }
    }

    private func readWarningsIfPresent(id: String, petsRoot: URL) -> [PetdexImporterWarningSidecarEntry]? {
        let url = petsRoot
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(ConvertedPetPackage.importWarningsFileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return readWarnings(id: id, petsRoot: petsRoot)
    }

    private func expectInvalidSpritesheetLayout(operation: () throws -> Void) {
        do {
            try operation()
            fail("expected invalidSpritesheetLayout error")
        } catch PetdexImportError.invalidSpritesheetLayout {
        } catch {
            fail("expected invalidSpritesheetLayout, got \(error)")
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
}

private struct PetdexImporterWarningSidecarEntry: Decodable, Equatable {
    let kind: String
    let detail: String
    let role: ActionRole?
    let actionId: ActionId?
}

private struct PetdexImporterActionsScratch {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetdexPackageImporterActionsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeZip(entries: [PetdexImporterActionsZipEntry]) -> URL {
        let url = root.appendingPathComponent("petdex.zip")
        do {
            try makeZipData(entries: entries).write(to: url)
        } catch {
            fail("could not write Petdex zip fixture: \(error)")
        }
        return url
    }

    private func makeZipData(entries: [PetdexImporterActionsZipEntry]) -> Data {
        var localData = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localHeaderOffset = localData.count
            let nameData = Data(entry.name.utf8)

            localData.appendPetdexImporterActionsZipUInt32(0x0403_4B50)
            localData.appendPetdexImporterActionsZipUInt16(20)
            localData.appendPetdexImporterActionsZipUInt16(0)
            localData.appendPetdexImporterActionsZipUInt16(0)
            localData.appendPetdexImporterActionsZipUInt16(0)
            localData.appendPetdexImporterActionsZipUInt16(0)
            localData.appendPetdexImporterActionsZipUInt32(0)
            localData.appendPetdexImporterActionsZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexImporterActionsZipUInt32(UInt32(entry.data.count))
            localData.appendPetdexImporterActionsZipUInt16(UInt16(nameData.count))
            localData.appendPetdexImporterActionsZipUInt16(0)
            localData.append(nameData)
            localData.append(entry.data)

            centralDirectory.appendPetdexImporterActionsZipUInt32(0x0201_4B50)
            centralDirectory.appendPetdexImporterActionsZipUInt16(20)
            centralDirectory.appendPetdexImporterActionsZipUInt16(20)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt32(0)
            centralDirectory.appendPetdexImporterActionsZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexImporterActionsZipUInt32(UInt32(entry.data.count))
            centralDirectory.appendPetdexImporterActionsZipUInt16(UInt16(nameData.count))
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt16(0)
            centralDirectory.appendPetdexImporterActionsZipUInt32(0)
            centralDirectory.appendPetdexImporterActionsZipUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = localData.count
        localData.append(centralDirectory)
        localData.appendPetdexImporterActionsZipUInt32(0x0605_4B50)
        localData.appendPetdexImporterActionsZipUInt16(0)
        localData.appendPetdexImporterActionsZipUInt16(0)
        localData.appendPetdexImporterActionsZipUInt16(UInt16(entries.count))
        localData.appendPetdexImporterActionsZipUInt16(UInt16(entries.count))
        localData.appendPetdexImporterActionsZipUInt32(UInt32(centralDirectory.count))
        localData.appendPetdexImporterActionsZipUInt32(UInt32(centralDirectoryOffset))
        localData.appendPetdexImporterActionsZipUInt16(0)

        return localData
    }
}

private struct PetdexImporterActionsZipEntry {
    let name: String
    let data: Data

    static func stored(name: String, data: Data) -> PetdexImporterActionsZipEntry {
        PetdexImporterActionsZipEntry(name: name, data: data)
    }
}

private extension Data {
    mutating func appendPetdexImporterActionsZipUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendPetdexImporterActionsZipUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}
