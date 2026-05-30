import CoreGraphics
import Foundation
import ImageIO
import DesktopPet

func runActionImageNormalizerTests() {
    let tests = ActionImageNormalizerTests()
    tests.normalizeSingleImageAtTargetSize()
    tests.normalizeSingleImageScalesLargerImage()
    tests.normalizeMultipleImagesSynthesizesHorizontal()
}

func runActionGridAnalyzerTests() {
    let tests = ActionGridAnalyzerTests()
    tests.analyzeSingleFrameImage()
    tests.analyzeFourFrameHorizontal()
    tests.analyzeFourByTwoGrid()
    tests.analyzeSuggestsMatchingPresets()
}

func runActionPackDraftBuilderTests() {
    let tests = ActionPackDraftBuilderTests()
    tests.buildDraftFromSingleImage()
    tests.buildDraftGeneratesValidManifest()
    tests.buildDraftWithCustomGrid()
    tests.buildDraftWithSelectedFrames()
    tests.buildDraftGeneratesSourceMetadata()
    tests.buildDraftWithNonASCIINameGeneratesValidIds()
}

// MARK: - Test Helpers

private let testFrameSize = CGSizeCodable(width: 64, height: 64)

private func makeTestPNGData(width: Int, height: Int) -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

private func imageSize(_ data: Data) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (w, h)
}

// MARK: - Image Normalizer Tests

private struct ActionImageNormalizerTests {

    func normalizeSingleImageAtTargetSize() {
        let normalizer = DefaultActionImageNormalizer()
        let imageData = makeTestPNGData(width: 64, height: 64)

        do {
            let result = try normalizer.normalize(
                .singleImage(imageData),
                targetFrameSize: testFrameSize
            )
            expect(result.width == 64, "width should be 64, got \(result.width)")
            expect(result.height == 64, "height should be 64, got \(result.height)")
        } catch {
            fail("normalize single image at target size should succeed; got \(error)")
        }
    }

    func normalizeSingleImageScalesLargerImage() {
        let normalizer = DefaultActionImageNormalizer()
        let imageData = makeTestPNGData(width: 200, height: 150)

        do {
            let result = try normalizer.normalize(
                .singleImage(imageData),
                targetFrameSize: testFrameSize
            )
            expect(result.width == 64, "width should be scaled to 64, got \(result.width)")
            expect(result.height == 64, "height should be scaled to 64, got \(result.height)")
        } catch {
            fail("normalize larger image should succeed; got \(error)")
        }
    }

    func normalizeMultipleImagesSynthesizesHorizontal() {
        let normalizer = DefaultActionImageNormalizer()
        let img1 = makeTestPNGData(width: 64, height: 64)
        let img2 = makeTestPNGData(width: 64, height: 64)
        let img3 = makeTestPNGData(width: 64, height: 64)

        do {
            let result = try normalizer.normalize(
                .multipleImages([img1, img2, img3]),
                targetFrameSize: testFrameSize
            )
            expect(result.width == 192, "width should be 64*3=192, got \(result.width)")
            expect(result.height == 64, "height should be 64, got \(result.height)")
        } catch {
            fail("normalize multiple images should succeed; got \(error)")
        }
    }
}

// MARK: - Grid Analyzer Tests

private struct ActionGridAnalyzerTests {

    func analyzeSingleFrameImage() {
        let analyzer = DefaultActionGridAnalyzer()
        let image = NormalizedActionImage(imageData: Data(), width: 64, height: 64)

        let result = analyzer.analyze(image, targetFrameSize: testFrameSize)
        expect(result.columns == 1, "single frame should have 1 column, got \(result.columns)")
        expect(result.rows == 1, "single frame should have 1 row, got \(result.rows)")
    }

    func analyzeFourFrameHorizontal() {
        let analyzer = DefaultActionGridAnalyzer()
        let image = NormalizedActionImage(imageData: Data(), width: 256, height: 64)

        let result = analyzer.analyze(image, targetFrameSize: testFrameSize)
        expect(result.columns == 4, "4-frame horizontal should have 4 columns, got \(result.columns)")
        expect(result.rows == 1, "4-frame horizontal should have 1 row, got \(result.rows)")
    }

    func analyzeFourByTwoGrid() {
        let analyzer = DefaultActionGridAnalyzer()
        let image = NormalizedActionImage(imageData: Data(), width: 256, height: 128)

        let result = analyzer.analyze(image, targetFrameSize: testFrameSize)
        expect(result.columns == 4, "4x2 grid should have 4 columns, got \(result.columns)")
        expect(result.rows == 2, "4x2 grid should have 2 rows, got \(result.rows)")
    }

    func analyzeSuggestsMatchingPresets() {
        let analyzer = DefaultActionGridAnalyzer()
        let image = NormalizedActionImage(imageData: Data(), width: 256, height: 64)

        let result = analyzer.analyze(image, targetFrameSize: testFrameSize)
        let hasFourByOne = result.suggestedPresets.contains { $0.columns == 4 && $0.rows == 1 }
        expect(hasFourByOne, "should suggest 4x1 preset for 4-column image")
    }
}

// MARK: - Draft Builder Tests

private struct ActionPackDraftBuilderTests {

    func buildDraftFromSingleImage() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 64, height: 64)

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "Wave",
                targetFrameSize: testFrameSize
            )
            expect(draft.manifest.actions.count == 1, "should have 1 action")
            expect(draft.manifest.resources.count == 1, "should have 1 resource")
            expect(draft.manifest.resources.first?.grid.columns == 1, "single image should be 1x1")
        } catch {
            fail("buildDraft from single image should succeed; got \(error)")
        }
    }

    func buildDraftGeneratesValidManifest() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 256, height: 64)

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "Walk Cycle",
                targetFrameSize: testFrameSize
            )
            let manifest = draft.manifest
            expect(manifest.schemaVersion == 1, "schemaVersion should be 1")
            expect(!manifest.id.isEmpty, "pack id should not be empty")
            expect(manifest.id == manifest.actions.first?.id.rawValue, "pack id should match action id")
            expect(manifest.resources.first?.id == manifest.actions.first?.assetId, "resource id should match action assetId")
        } catch {
            fail("manifest generation should succeed; got \(error)")
        }
    }

    func buildDraftWithCustomGrid() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 256, height: 128)

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "Complex",
                targetFrameSize: testFrameSize,
                gridOverride: (columns: 4, rows: 2)
            )
            let resource = draft.manifest.resources.first
            expect(resource?.grid.columns == 4, "grid columns should be 4")
            expect(resource?.grid.rows == 2, "grid rows should be 2")
            expect(draft.manifest.actions.first?.frames.count == 8, "should have 8 frames for 4x2 grid")
        } catch {
            fail("buildDraft with custom grid should succeed; got \(error)")
        }
    }

    func buildDraftWithSelectedFrames() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 256, height: 64)

        let selectedFrames = [
            ActionFrameSelection(column: 0, row: 0),
            ActionFrameSelection(column: 2, row: 0),
            ActionFrameSelection(column: 3, row: 0)
        ]

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "Selected",
                targetFrameSize: testFrameSize,
                selectedFrames: selectedFrames
            )
            let action = draft.manifest.actions.first
            expect(action?.frames.count == 3, "should have 3 selected frames")
            expect(action?.frames[0].column == 0, "first frame col should be 0")
            expect(action?.frames[1].column == 2, "second frame col should be 2")
        } catch {
            fail("buildDraft with selected frames should succeed; got \(error)")
        }
    }

    func buildDraftGeneratesSourceMetadata() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 64, height: 64)

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "Test",
                targetFrameSize: testFrameSize,
                source: .localImage
            )
            expect(draft.sourceMetadata != nil, "source metadata should be generated")
            expect(draft.sourceMetadata?.source == .localImage, "source should be localImage")
        } catch {
            fail("source metadata generation should succeed; got \(error)")
        }
    }

    func buildDraftWithNonASCIINameGeneratesValidIds() {
        let builder = ActionPackDraftBuilder()
        let imageData = makeTestPNGData(width: 64, height: 64)

        do {
            let draft = try builder.buildDraft(
                input: .singleImage(imageData),
                displayName: "挥手",
                targetFrameSize: testFrameSize
            )

            expect(draft.manifest.id.hasPrefix("action_"), "non-ASCII names should use a safe fallback pack id")
            expect(draft.manifest.actions.first?.id.rawValue == draft.manifest.id, "action id should match pack id")
            expect(draft.manifest.resources.first?.id == "action_sheet", "resource id should use the safe fallback slug")
        } catch {
            fail("buildDraft should sanitize non-ASCII display names instead of crashing; got \(error)")
        }
    }
}
