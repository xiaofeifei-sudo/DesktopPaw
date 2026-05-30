import Foundation
@preconcurrency import AppKit
import DesktopPet

func runPetImageImporterTests() {
    let tests = PetImageImporterTests()
    tests.importsPNGSuccessfully()
    tests.importsJPGSuccessfully()
    tests.importsJPEGSuccessfully()
    tests.rejectsNonImageExtension()
    tests.rejectsUnreadableImage()
    tests.downscalesLargeImageMain()
    tests.downscalesLargeImagePreview()
    tests.preservesPNGAlpha()
    tests.rejectsOversizedFile()
    tests.copiesAreIndependentOfSource()
    tests.smallImageIsNotUpscaled()
}

private struct PetImageImporterTests {
    func importsPNGSuccessfully() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("source.png")
        scratch.writeTestImage(to: sourceURL, width: 200, height: 100, type: .png, hasAlpha: true)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        let result: ImportedPetImage
        do {
            result = try importer.importImage(from: sourceURL, to: destination, displayName: "Test")
        } catch {
            fail("PNG import should succeed: \(error)")
        }

        expect(result.imageFileName == PetImageImporter.imageFileName, "main image filename should match constant")
        expect(result.previewFileName == PetImageImporter.previewFileName, "preview filename should match constant")
        expect(result.pixelSize.width > 0 && result.pixelSize.height > 0, "pixel size must be positive")

        let mainPath = destination.appendingPathComponent(PetImageImporter.imageFileName).path
        let previewPath = destination.appendingPathComponent(PetImageImporter.previewFileName).path
        expect(FileManager.default.fileExists(atPath: mainPath), "main image file should exist")
        expect(FileManager.default.fileExists(atPath: previewPath), "preview file should exist")
    }

    func importsJPGSuccessfully() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("source.jpg")
        scratch.writeTestImage(to: sourceURL, width: 100, height: 100, type: .jpeg, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Test")
        } catch {
            fail("JPG import should succeed: \(error)")
        }

        let mainPath = destination.appendingPathComponent(PetImageImporter.imageFileName).path
        expect(FileManager.default.fileExists(atPath: mainPath), "JPG should produce image.png")
    }

    func importsJPEGSuccessfully() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("source.jpeg")
        scratch.writeTestImage(to: sourceURL, width: 100, height: 100, type: .jpeg, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Test")
        } catch {
            fail("JPEG (.jpeg) import should succeed: \(error)")
        }

        let mainPath = destination.appendingPathComponent(PetImageImporter.imageFileName).path
        expect(FileManager.default.fileExists(atPath: mainPath), "JPEG should produce image.png")
    }

    func rejectsNonImageExtension() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("note.txt")
        do {
            try Data("not an image".utf8).write(to: sourceURL)
        } catch {
            fail("could not seed text file: \(error)")
        }

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Test")
            fail("non-image extension should be rejected")
        } catch let error as PetLibraryError {
            expect(error == .unsupportedImageType, "expected unsupportedImageType, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }

        expect(
            !FileManager.default.fileExists(atPath: destination.path),
            "destination folder should not be created when extension rejected"
        )
    }

    func rejectsUnreadableImage() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("broken.png")
        do {
            try Data("not actually a PNG".utf8).write(to: sourceURL)
        } catch {
            fail("could not seed broken png: \(error)")
        }

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Test")
            fail("invalid PNG bytes should fail")
        } catch let error as PetLibraryError {
            expect(error == .unreadableImage, "expected unreadableImage, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }

    func downscalesLargeImageMain() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("big.png")
        scratch.writeTestImage(to: sourceURL, width: 2048, height: 1024, type: .png, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        let result: ImportedPetImage
        do {
            result = try importer.importImage(from: sourceURL, to: destination, displayName: "Big")
        } catch {
            fail("import of large image should succeed: \(error)")
        }

        let limit = Double(PetImageImporter.defaultMainImageMaxLongestSide)
        expect(result.pixelSize.width <= limit, "main image width should be <= \(limit), got \(result.pixelSize.width)")
        expect(result.pixelSize.height <= limit, "main image height should be <= \(limit), got \(result.pixelSize.height)")
        expect(result.pixelSize.width == limit, "longest side should be scaled to \(limit), got \(result.pixelSize.width)")
        expect(result.pixelSize.height == limit / 2, "aspect ratio should be preserved, got \(result.pixelSize.height)")
    }

    func downscalesLargeImagePreview() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("big.png")
        scratch.writeTestImage(to: sourceURL, width: 2048, height: 1024, type: .png, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Big")
        } catch {
            fail("import should succeed: \(error)")
        }

        let previewURL = destination.appendingPathComponent(PetImageImporter.previewFileName)
        guard let preview = NSImage(contentsOf: previewURL),
              let tiff = preview.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            fail("preview should be loadable")
        }

        let limit = PetImageImporter.defaultPreviewMaxLongestSide
        expect(rep.pixelsWide <= limit, "preview width should be <= \(limit), got \(rep.pixelsWide)")
        expect(rep.pixelsHigh <= limit, "preview height should be <= \(limit), got \(rep.pixelsHigh)")
        expect(rep.pixelsWide == limit, "preview longest side should be \(limit), got \(rep.pixelsWide)")
        expect(rep.pixelsHigh == limit / 2, "preview aspect ratio should be preserved, got \(rep.pixelsHigh)")
    }

    func preservesPNGAlpha() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("alpha.png")
        scratch.writeTestImage(to: sourceURL, width: 100, height: 100, type: .png, hasAlpha: true)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        let result: ImportedPetImage
        do {
            result = try importer.importImage(from: sourceURL, to: destination, displayName: "Alpha")
        } catch {
            fail("alpha import should succeed: \(error)")
        }

        expect(result.hasAlpha, "alpha PNG should report hasAlpha=true")

        let mainURL = destination.appendingPathComponent(PetImageImporter.imageFileName)
        guard let main = NSImage(contentsOf: mainURL),
              let tiff = main.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            fail("main image should load")
        }
        expect(rep.hasAlpha, "saved PNG should still report alpha")
    }

    func rejectsOversizedFile() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("huge.png")
        scratch.writeTestImage(to: sourceURL, width: 100, height: 100, type: .png, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter(maxFileBytes: 16)

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Big")
            fail("oversized file should be rejected")
        } catch let error as PetLibraryError {
            expect(error == .imageTooLarge, "expected imageTooLarge, got \(error)")
        } catch {
            fail("expected PetLibraryError, got \(error)")
        }
    }

    func copiesAreIndependentOfSource() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("temp.png")
        scratch.writeTestImage(to: sourceURL, width: 64, height: 64, type: .png, hasAlpha: false)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        do {
            _ = try importer.importImage(from: sourceURL, to: destination, displayName: "Temp")
        } catch {
            fail("import should succeed: \(error)")
        }

        do {
            try FileManager.default.removeItem(at: sourceURL)
        } catch {
            fail("could not delete source: \(error)")
        }

        let mainURL = destination.appendingPathComponent(PetImageImporter.imageFileName)
        let previewURL = destination.appendingPathComponent(PetImageImporter.previewFileName)
        expect(FileManager.default.fileExists(atPath: mainURL.path), "main image should still exist after source delete")
        expect(FileManager.default.fileExists(atPath: previewURL.path), "preview should still exist after source delete")
        expect(NSImage(contentsOf: mainURL) != nil, "main image should remain loadable after source delete")
    }

    func smallImageIsNotUpscaled() {
        let scratch = makeScratch()
        defer { scratch.cleanUp() }

        let sourceURL = scratch.root.appendingPathComponent("small.png")
        scratch.writeTestImage(to: sourceURL, width: 80, height: 40, type: .png, hasAlpha: true)

        let destination = scratch.root.appendingPathComponent("imported", isDirectory: true)
        let importer = PetImageImporter()

        let result: ImportedPetImage
        do {
            result = try importer.importImage(from: sourceURL, to: destination, displayName: "Small")
        } catch {
            fail("small image import should succeed: \(error)")
        }

        expect(result.pixelSize.width == 80, "small image width should not be upscaled, got \(result.pixelSize.width)")
        expect(result.pixelSize.height == 40, "small image height should not be upscaled, got \(result.pixelSize.height)")
    }

    private func makeScratch() -> Scratch {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopPetImporterTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Scratch(root: root)
    }
}

private struct Scratch {
    let root: URL

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeTestImage(
        to url: URL,
        width: Int,
        height: Int,
        type: NSBitmapImageRep.FileType,
        hasAlpha: Bool
    ) {
        let bitmapInfo: UInt32 = hasAlpha
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            fail("could not create test image context")
        }

        let alpha: CGFloat = hasAlpha ? 0.5 : 1.0
        context.setFillColor(red: 0.95, green: 0.4, blue: 0.4, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            fail("could not create test cgImage")
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        let properties: [NSBitmapImageRep.PropertyKey: Any]
        switch type {
        case .jpeg:
            properties = [.compressionFactor: 0.9]
        default:
            properties = [:]
        }

        guard let data = rep.representation(using: type, properties: properties) else {
            fail("could not encode test image")
        }

        do {
            try data.write(to: url)
        } catch {
            fail("could not write test image: \(error)")
        }
    }
}
