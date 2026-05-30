import Foundation
import ImageIO
@preconcurrency import AppKit
import DesktopPet

func runPetdexSpriteSheetProcessorTests() {
    let tests = PetdexSpriteSheetProcessorTests()
    tests.processesWebPSpriteSheet()
    tests.processesPNGSpritesheetAndDerivesPetdexFrameSize()
    tests.detectsTrailingTransparentFramesByRow()
    tests.previewUsesFirstFrameDimensions()
    tests.rejectsInvalidImageData()
    tests.rejectsMismatchedGridDimensions()
    tests.rejectsOversizedImage()
}

private struct PetdexSpriteSheetProcessorTests {
    func processesWebPSpriteSheet() {
        let data = Data(base64Encoded: webp8x9FixtureBase64) ?? Data()
        let processor = PetdexSpriteSheetProcessor()

        let result: ProcessedPetdexSpriteSheet
        do {
            result = try processor.process(
                data: data,
                sourceFileName: "spritesheet.webp",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        } catch {
            fail("WebP spritesheet should process successfully: \(error)")
        }

        expect(result.pixelSize == CGSizeCodable(width: 8, height: 9), "WebP pixel size should decode")
        expect(result.frameSize == CGSizeCodable(width: 1, height: 1), "WebP frame size should derive from 8x9 grid")
        expect(result.hasAlpha, "WebP fixture should preserve alpha")
        expect(loadBitmap(from: result.spritesheetPNGData)?.pixelsWide == 8, "WebP should convert to loadable PNG spritesheet")
    }

    func processesPNGSpritesheetAndDerivesPetdexFrameSize() {
        let data = makePNGData(width: 1536, height: 1872, hasAlpha: true)
        let processor = PetdexSpriteSheetProcessor()

        let result: ProcessedPetdexSpriteSheet
        do {
            result = try processor.process(
                data: data,
                sourceFileName: "spritesheet.png",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        } catch {
            fail("PNG spritesheet should process successfully: \(error)")
        }

        expect(result.pixelSize == CGSizeCodable(width: 1536, height: 1872), "PNG pixel size should be preserved")
        expect(result.frameSize == CGSizeCodable(width: 192, height: 208), "1536x1872 should derive 192x208 frames")
        expect(result.columns == 8 && result.rows == 9, "grid dimensions should be preserved")
        expect(result.hasAlpha, "PNG alpha should be detected")
        expect(result.nonEmptyFrameCountsByRow[0] == 8, "fully visible rows should keep all columns")

        guard let spritesheet = loadBitmap(from: result.spritesheetPNGData) else {
            fail("processed spritesheet PNG should be loadable")
        }
        expect(spritesheet.pixelsWide == 1536, "processed spritesheet width should remain 1536")
        expect(spritesheet.pixelsHigh == 1872, "processed spritesheet height should remain 1872")
        expect(spritesheet.hasAlpha, "processed PNG should preserve alpha")
    }

    func detectsTrailingTransparentFramesByRow() {
        let data = makeSparsePNGData(
            columns: 4,
            rows: 2,
            frameWidth: 2,
            frameHeight: 2,
            filledFrames: [
                SpriteFrame(column: 0, row: 0),
                SpriteFrame(column: 1, row: 0),
                SpriteFrame(column: 0, row: 1),
                SpriteFrame(column: 1, row: 1),
                SpriteFrame(column: 2, row: 1)
            ]
        )
        let processor = PetdexSpriteSheetProcessor()

        let result: ProcessedPetdexSpriteSheet
        do {
            result = try processor.process(
                data: data,
                sourceFileName: "spritesheet.png",
                convention: PetdexSpriteSheetConvention(columns: 4, rows: 2)
            )
        } catch {
            fail("sparse PNG spritesheet should process successfully: \(error)")
        }

        expect(result.nonEmptyFrameCountsByRow[0] == 2, "row 0 should trim trailing transparent frames")
        expect(result.nonEmptyFrameCountsByRow[1] == 3, "row 1 should keep frames through the last visible column")
    }

    func previewUsesFirstFrameDimensions() {
        let data = makePNGData(width: 16, height: 18, hasAlpha: true)
        let processor = PetdexSpriteSheetProcessor()

        let result: ProcessedPetdexSpriteSheet
        do {
            result = try processor.process(
                data: data,
                sourceFileName: "spritesheet.png",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        } catch {
            fail("PNG spritesheet should process preview successfully: \(error)")
        }

        guard let preview = loadBitmap(from: result.previewPNGData) else {
            fail("preview PNG should be loadable")
        }
        expect(preview.pixelsWide == 2, "preview width should match first frame width")
        expect(preview.pixelsHigh == 2, "preview height should match first frame height")
        expect(preview.hasAlpha, "preview PNG should preserve alpha")
    }

    func rejectsInvalidImageData() {
        expectPetdexError(.unreadableImage("spritesheet.webp")) {
            _ = try PetdexSpriteSheetProcessor().process(
                data: Data("not an image".utf8),
                sourceFileName: "spritesheet.webp",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        }
    }

    func rejectsMismatchedGridDimensions() {
        let data = makePNGData(width: 10, height: 9, hasAlpha: true)

        expectPetdexError(
            .invalidSpritesheetLayout("image dimensions 10x9 are not divisible by 8x9")
        ) {
            _ = try PetdexSpriteSheetProcessor().process(
                data: data,
                sourceFileName: "spritesheet.png",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        }
    }

    func rejectsOversizedImage() {
        let data = makePNGData(width: 8, height: 9, hasAlpha: true)

        expectPetdexError(.imageTooLarge(maximumPixels: 16)) {
            _ = try PetdexSpriteSheetProcessor(maximumPixels: 16).process(
                data: data,
                sourceFileName: "spritesheet.png",
                convention: PetdexSpriteSheetConvention(columns: 8, rows: 9)
            )
        }
    }

    private func makePNGData(width: Int, height: Int, hasAlpha: Bool) -> Data {
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
            fail("could not create PNG test context")
        }

        if hasAlpha {
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.setFillColor(red: 0.2, green: 0.7, blue: 0.9, alpha: hasAlpha ? 0.6 : 1.0)
        context.fill(CGRect(x: 0, y: 0, width: max(1, width), height: max(1, height)))

        guard let image = context.makeImage() else {
            fail("could not create PNG test image")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            fail("could not create PNG destination")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fail("could not encode PNG test data")
        }

        return output as Data
    }

    private func makeSparsePNGData(
        columns: Int,
        rows: Int,
        frameWidth: Int,
        frameHeight: Int,
        filledFrames: [SpriteFrame]
    ) -> Data {
        let width = columns * frameWidth
        let height = rows * frameHeight
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for frame in filledFrames {
            for y in (frame.row * frameHeight)..<((frame.row + 1) * frameHeight) {
                for x in (frame.column * frameWidth)..<((frame.column + 1) * frameWidth) {
                    let offset = (y * width + x) * 4
                    pixels[offset] = 230
                    pixels[offset + 1] = 50
                    pixels[offset + 2] = 80
                    pixels[offset + 3] = 255
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
            fail("could not create sparse PNG test image")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            fail("could not create sparse PNG destination")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fail("could not encode sparse PNG test data")
        }

        return output as Data
    }

    private func loadBitmap(from data: Data) -> NSBitmapImageRep? {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation else {
            return nil
        }
        return NSBitmapImageRep(data: tiff)
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

    private var webp8x9FixtureBase64: String {
        "UklGRiIAAABXRUJQVlA4TBYAAAAvBwACEA8Q8x8DGAyBQNL+3DtE9D8s"
    }
}
