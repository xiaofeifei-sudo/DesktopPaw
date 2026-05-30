import CoreGraphics
import Foundation
import ImageIO

public protocol PetdexSpriteSheetProcessing {
    func process(
        data: Data,
        sourceFileName: String,
        convention: PetdexSpriteSheetConvention
    ) throws -> ProcessedPetdexSpriteSheet
}

public struct PetdexSpriteSheetConvention: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let frameSize: CGSizeCodable
    public let stateRows: [PetState: Int]
    public let framesPerState: [PetState: Int]
    public let frameDurationsMs: [PetState: Int]
    public let previewFrame: SpriteFrame

    public init(
        columns: Int,
        rows: Int,
        frameSize: CGSizeCodable = CGSizeCodable(width: 0, height: 0),
        stateRows: [PetState: Int] = [:],
        framesPerState: [PetState: Int] = [:],
        frameDurationsMs: [PetState: Int] = [:],
        previewFrame: SpriteFrame = SpriteFrame(column: 0, row: 0)
    ) {
        self.columns = columns
        self.rows = rows
        self.frameSize = frameSize
        self.stateRows = stateRows
        self.framesPerState = framesPerState
        self.frameDurationsMs = frameDurationsMs
        self.previewFrame = previewFrame
    }
}

public struct ProcessedPetdexSpriteSheet: Equatable, Sendable {
    public static let spritesheetFileName = "spritesheet.png"
    public static let previewFileName = "preview.png"

    public let spritesheetPNGData: Data
    public let previewPNGData: Data
    public let pixelSize: CGSizeCodable
    public let frameSize: CGSizeCodable
    public let columns: Int
    public let rows: Int
    public let hasAlpha: Bool
    public let nonEmptyFrameCountsByRow: [Int: Int]

    public init(
        spritesheetPNGData: Data,
        previewPNGData: Data,
        pixelSize: CGSizeCodable,
        frameSize: CGSizeCodable,
        columns: Int,
        rows: Int,
        hasAlpha: Bool,
        nonEmptyFrameCountsByRow: [Int: Int] = [:]
    ) {
        self.spritesheetPNGData = spritesheetPNGData
        self.previewPNGData = previewPNGData
        self.pixelSize = pixelSize
        self.frameSize = frameSize
        self.columns = columns
        self.rows = rows
        self.hasAlpha = hasAlpha
        self.nonEmptyFrameCountsByRow = nonEmptyFrameCountsByRow
    }
}

public final class PetdexSpriteSheetProcessor: PetdexSpriteSheetProcessing {
    public static let defaultMaximumPixels = 4096 * 4096
    public static let supportedExtensions: Set<String> = ["png", "webp"]

    private let maximumPixels: Int

    public init(maximumPixels: Int = PetdexSpriteSheetProcessor.defaultMaximumPixels) {
        self.maximumPixels = maximumPixels
    }

    public func process(
        data: Data,
        sourceFileName: String,
        convention: PetdexSpriteSheetConvention
    ) throws -> ProcessedPetdexSpriteSheet {
        try validateSourceFileName(sourceFileName)
        try validateConvention(convention)

        let image = try decodedImage(from: data, sourceFileName: sourceFileName)
        try validatePixelSize(width: image.width, height: image.height)

        guard image.width % convention.columns == 0,
              image.height % convention.rows == 0 else {
            throw PetdexImportError.invalidSpritesheetLayout(
                "image dimensions \(image.width)x\(image.height) are not divisible by \(convention.columns)x\(convention.rows)"
            )
        }

        let frameWidth = image.width / convention.columns
        let frameHeight = image.height / convention.rows
        try validatePreviewFrame(convention.previewFrame, columns: convention.columns, rows: convention.rows)

        let spritesheetPNGData = try pngData(from: image)
        let previewPNGData = try previewPNGData(
            from: image,
            frame: convention.previewFrame,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        )

        return ProcessedPetdexSpriteSheet(
            spritesheetPNGData: spritesheetPNGData,
            previewPNGData: previewPNGData,
            pixelSize: CGSizeCodable(width: Double(image.width), height: Double(image.height)),
            frameSize: CGSizeCodable(width: Double(frameWidth), height: Double(frameHeight)),
            columns: convention.columns,
            rows: convention.rows,
            hasAlpha: image.desktopPetHasAlpha,
            nonEmptyFrameCountsByRow: nonEmptyFrameCountsByRow(
                from: image,
                columns: convention.columns,
                rows: convention.rows,
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        )
    }

    private func validateSourceFileName(_ sourceFileName: String) throws {
        let fileExtension = URL(fileURLWithPath: sourceFileName).pathExtension.lowercased()
        guard Self.supportedExtensions.contains(fileExtension) else {
            throw PetdexImportError.unsupportedImageFormat(sourceFileName)
        }
    }

    private func validateConvention(_ convention: PetdexSpriteSheetConvention) throws {
        guard convention.columns > 0, convention.rows > 0 else {
            throw PetdexImportError.invalidSpritesheetLayout("grid columns and rows must be greater than zero")
        }
    }

    private func validatePreviewFrame(_ frame: SpriteFrame, columns: Int, rows: Int) throws {
        guard frame.column >= 0,
              frame.row >= 0,
              frame.column < columns,
              frame.row < rows else {
            throw PetdexImportError.invalidSpritesheetLayout("preview frame is outside the spritesheet grid")
        }
    }

    private func decodedImage(from data: Data, sourceFileName: String) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == "public.png" || type == "org.webmproject.webp",
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PetdexImportError.unreadableImage(sourceFileName)
        }

        return image
    }

    private func validatePixelSize(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw PetdexImportError.invalidImageDimensions
        }

        guard maximumPixels > 0,
              width <= maximumPixels / height else {
            throw PetdexImportError.imageTooLarge(maximumPixels: maximumPixels)
        }
    }

    private func previewPNGData(
        from image: CGImage,
        frame: SpriteFrame,
        frameWidth: Int,
        frameHeight: Int
    ) throws -> Data {
        let cropRect = CGRect(
            x: frame.column * frameWidth,
            y: frame.row * frameHeight,
            width: frameWidth,
            height: frameHeight
        )

        guard let preview = image.cropping(to: cropRect) else {
            throw PetdexImportError.invalidSpritesheetLayout("preview frame could not be cropped")
        }

        return try pngData(from: preview)
    }

    private func nonEmptyFrameCountsByRow(
        from image: CGImage,
        columns: Int,
        rows: Int,
        frameWidth: Int,
        frameHeight: Int
    ) -> [Int: Int] {
        guard image.desktopPetHasAlpha else {
            return Dictionary(uniqueKeysWithValues: (0..<rows).map { ($0, columns) })
        }

        var counts: [Int: Int] = [:]
        for row in 0..<rows {
            var lastNonEmptyColumn: Int?
            for column in 0..<columns {
                let frame = SpriteFrame(column: column, row: row)
                if !image.desktopPetFrameIsFullyTransparent(cropRect(
                    for: frame,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight
                )) {
                    lastNonEmptyColumn = column
                }
            }
            counts[row] = (lastNonEmptyColumn ?? 0) + 1
        }
        return counts
    }

    private func cropRect(
        for frame: SpriteFrame,
        frameWidth: Int,
        frameHeight: Int
    ) -> CGRect {
        CGRect(
            x: frame.column * frameWidth,
            y: frame.row * frameHeight,
            width: frameWidth,
            height: frameHeight
        )
    }

    private func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw PetdexImportError.unreadableImage(ProcessedPetdexSpriteSheet.spritesheetFileName)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PetdexImportError.unreadableImage(ProcessedPetdexSpriteSheet.spritesheetFileName)
        }

        return data as Data
    }
}
