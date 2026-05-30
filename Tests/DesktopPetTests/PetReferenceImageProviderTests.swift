import Foundation
import DesktopPet
import AppKit

@MainActor
func runPetReferenceImageProviderTests() {
    let tests = PetReferenceImageProviderTests()
    tests.exportReferenceImageCreatesFile()
    tests.exportReferenceImageOverwritesExisting()
}

@MainActor
private struct PetReferenceImageProviderTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-ref-provider-\(UUID().uuidString)")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func makeTestImage() -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.green.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    func exportReferenceImageCreatesFile() {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let provider = PetReferenceImageProvider(baseDirectory: dir)
        let image = makeTestImage()

        let url = try! provider.exportReferenceImage(petId: "cat-1", image: image)

        expect(fm.fileExists(atPath: url.path), "reference image file should exist")
        expect(url.lastPathComponent == "reference.png", "file should be named reference.png")
        expect(url.path.contains("cat-1/visual-actions/ref"), "file should be in correct path")

        let data = try! Data(contentsOf: url)
        expect(data.count > 0, "file should have content")

        let loaded = NSImage(contentsOf: url)
        expect(loaded != nil, "file should be a valid image")
    }

    func exportReferenceImageOverwritesExisting() {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let provider = PetReferenceImageProvider(baseDirectory: dir)

        let image1 = makeTestImage()
        let url1 = try! provider.exportReferenceImage(petId: "cat-1", image: image1)

        let size = NSSize(width: 32, height: 32)
        let image2 = NSImage(size: size)
        image2.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(origin: .zero, size: size))
        image2.unlockFocus()

        let url2 = try! provider.exportReferenceImage(petId: "cat-1", image: image2)

        expect(url1 == url2, "should overwrite same location")
        expect(fm.fileExists(atPath: url2.path), "file should still exist after overwrite")
    }
}
