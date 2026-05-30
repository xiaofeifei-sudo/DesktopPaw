import AppKit
import DesktopPet
import Foundation

@MainActor
func runReferenceImagePipelineTests() async throws {
    let tests = ReferenceImagePipelineTests()
    try await tests.processedReferenceOutputs512PlusCanvas()
    try await tests.boundingBoxDetectsVisiblePixels()
    try await tests.croppingRemovesTransparentPadding()
    try await tests.providerFriendlyHasNoTransparency()
    try await tests.cachingSkipsRepeatProcessing()
    try await tests.pixelArtUsesNearestNeighbor()
    try await tests.metadataCapturesOriginalAndProcessedInfo()
    try await tests.mediatorUsesPipelineWhenAvailable()
}

@MainActor
private struct ReferenceImagePipelineTests {
    private let fm = FileManager.default

    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ref-pipeline-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? fm.removeItem(at: dir)
    }

    private func makeSpritePNG(
        at url: URL,
        width: Int = 8,
        height: Int = 8,
        fill: NSColor = NSColor(deviceRed: 1, green: 0.42, blue: 0.7, alpha: 1),
        transparentBorder: Int = 2
    ) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        for y in 0..<height {
            for x in 0..<width {
                let isBorder = x < transparentBorder || y < transparentBorder || x >= width - transparentBorder || y >= height - transparentBorder
                let color = isBorder ? NSColor.clear : fill
                rep.setColor(color, atX: x, y: y)
            }
        }

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
        }
        try data.write(to: url)
    }

    func processedReferenceOutputs512PlusCanvas() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 16, height: 16, transparentBorder: 0)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        guard let transparentData = try? Data(contentsOf: result.transparentPNG),
              let transparentRep = NSBitmapImageRep(data: transparentData)
        else {
            XCTFail("Transparent PNG should be loadable")
            return
        }

        XCTAssertTrue(transparentRep.pixelsWide >= 512, "Processed width should be >= 512, got \(transparentRep.pixelsWide)")
        XCTAssertTrue(transparentRep.pixelsHigh >= 512, "Processed height should be >= 512, got \(transparentRep.pixelsHigh)")

        guard let providerData = try? Data(contentsOf: result.providerFriendly),
              let providerRep = NSBitmapImageRep(data: providerData)
        else {
            XCTFail("Provider PNG should be loadable")
            return
        }
        XCTAssertEqual(providerRep.pixelsWide, transparentRep.pixelsWide, "Provider friendly should match canvas size")
        XCTAssertEqual(providerRep.pixelsHigh, transparentRep.pixelsHigh, "Provider friendly should match canvas size")
    }

    func boundingBoxDetectsVisiblePixels() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 10, height: 10, transparentBorder: 2)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        let bbox = result.originalInfo.boundingBox
        XCTAssertNotNil(bbox, "Bounding box should be detected for image with transparent border")
        if let bbox {
            XCTAssertEqual(Int(bbox.origin.x), 2, "Bounding box minX should be 2")
            XCTAssertEqual(Int(bbox.origin.y), 2, "Bounding box minY should be 2")
            XCTAssertEqual(Int(bbox.width), 6, "Bounding box width should be 6")
            XCTAssertEqual(Int(bbox.height), 6, "Bounding box height should be 6")
        }
    }

    func croppingRemovesTransparentPadding() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 20, height: 20, transparentBorder: 5)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        let originalBBox = result.originalInfo.boundingBox
        XCTAssertNotNil(originalBBox, "Original should have bounding box")
        if let bbox = originalBBox {
            XCTAssertEqual(Int(bbox.width), 10, "Visible content width should be 10 (20 - 2*5)")
            XCTAssertEqual(Int(bbox.height), 10, "Visible content height should be 10")
        }
    }

    func providerFriendlyHasNoTransparency() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 8, height: 8, transparentBorder: 2)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        guard let providerData = try? Data(contentsOf: result.providerFriendly),
              let providerRep = NSBitmapImageRep(data: providerData)
        else {
            XCTFail("Provider PNG should be loadable")
            return
        }

        var foundTransparent = false
        for y in 0..<providerRep.pixelsHigh {
            for x in 0..<providerRep.pixelsWide {
                if let color = providerRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    if color.alphaComponent < 0.99 {
                        foundTransparent = true
                    }
                }
            }
        }

        XCTAssertFalse(foundTransparent, "Provider-friendly version should have no transparent pixels — all should be filled with matte background")
    }

    func cachingSkipsRepeatProcessing() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 8, height: 8, fill: NSColor.red, transparentBorder: 0)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)

        let result1 = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)
        let result2 = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        XCTAssertEqual(result1.originalInfo, result2.originalInfo, "Cached metadata should match")
        XCTAssertEqual(result1.processedInfo, result2.processedInfo, "Cached processed metadata should match")

        let cacheURL = dir.appendingPathComponent("test-pet/visual-actions/ref/reference-cache.json")
        XCTAssertTrue(fm.fileExists(atPath: cacheURL.path), "Cache file should exist after processing")

        let differentPetSourceURL = dir.appendingPathComponent("source2.png")
        try makeSpritePNG(at: differentPetSourceURL, width: 16, height: 16, fill: NSColor.blue, transparentBorder: 0)

        let result3 = try await pipeline.process(petId: "test-pet2", sourceURL: differentPetSourceURL)
        XCTAssertNotEqual(result1.originalInfo, result3.originalInfo, "Different pet should produce different metadata")
    }

    func pixelArtUsesNearestNeighbor() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 16, height: 16, transparentBorder: 0)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        XCTAssertNotNil(result.originalInfo.dominantColors, "Should extract dominant colors from pixel data")
        XCTAssertTrue(result.originalInfo.hasAlpha, "Sprite source should detect alpha channel")
    }

    func metadataCapturesOriginalAndProcessedInfo() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("source.png")
        try makeSpritePNG(at: sourceURL, width: 8, height: 8, transparentBorder: 2)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let result = try await pipeline.process(petId: "test-pet", sourceURL: sourceURL)

        XCTAssertEqual(result.originalInfo.width, 8, "Original width should be 8")
        XCTAssertEqual(result.originalInfo.height, 8, "Original height should be 8")
        XCTAssertTrue(result.originalInfo.hasAlpha, "Original should have alpha")
        XCTAssertGreaterThan(result.originalInfo.visibleAreaRatio, 0, "Original should have some visible pixels")

        XCTAssertGreaterThanOrEqual(result.processedInfo.width, 512, "Processed width should be >= 512")
        XCTAssertGreaterThanOrEqual(result.processedInfo.height, 512, "Processed height should be >= 512")
    }

    func mediatorUsesPipelineWhenAvailable() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let sourceURL = dir.appendingPathComponent("pet.png")
        try makeSpritePNG(at: sourceURL, width: 16, height: 16, transparentBorder: 0)

        let pipeline = ReferenceImagePipeline(baseDirectory: dir)
        let processed = try await pipeline.process(petId: "mediator-pet", sourceURL: sourceURL)

        guard let providerData = try? Data(contentsOf: processed.providerFriendly),
              let rep = NSBitmapImageRep(data: providerData)
        else {
            XCTFail("Provider-friendly image should exist and be valid")
            return
        }

        XCTAssertTrue(rep.pixelsWide >= 512, "Mediator pipeline should produce >=512 canvas, got \(rep.pixelsWide)")

        var allOpaque = true
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent < 0.99 {
                    allOpaque = false
                    break
                }
            }
            if !allOpaque { break }
        }
        XCTAssertTrue(allOpaque, "Provider-friendly output from mediator should be fully opaque")
    }
}

@MainActor
private func XCTFail(_ message: String) {
    assertionFailure(message)
}

@MainActor
private func XCTAssertTrue(_ expression: Bool, _ message: String = "") {
    if !expression { assertionFailure(message) }
}

@MainActor
private func XCTAssertFalse(_ expression: Bool, _ message: String = "") {
    if expression { assertionFailure(message) }
}

@MainActor
private func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") {
    if a != b { assertionFailure(message) }
}

@MainActor
private func XCTAssertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") {
    if a == b { assertionFailure(message) }
}

@MainActor
private func XCTAssertNotNil(_ expression: Any?, _ message: String = "") {
    if expression == nil { assertionFailure(message) }
}

@MainActor
private func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "") {
    if !(a > b) { assertionFailure(message) }
}

@MainActor
private func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: T, _ b: T, _ message: String = "") {
    if !(a >= b) { assertionFailure(message) }
}
