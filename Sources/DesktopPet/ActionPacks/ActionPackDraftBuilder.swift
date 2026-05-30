import CoreGraphics
import Foundation
import ImageIO

public struct ActionPackDraftBuilder: Sendable {
    private let imageNormalizer: ActionImageNormalizing
    private let gridAnalyzer: ActionGridAnalyzing

    public init(
        imageNormalizer: ActionImageNormalizing = DefaultActionImageNormalizer(),
        gridAnalyzer: ActionGridAnalyzing = DefaultActionGridAnalyzer()
    ) {
        self.imageNormalizer = imageNormalizer
        self.gridAnalyzer = gridAnalyzer
    }

    public func buildDraft(
        input: ActionImageInput,
        displayName: String,
        targetFrameSize: CGSizeCodable,
        frameDurationMs: Int = 160,
        loop: Bool = false,
        nextActionId: ActionId? = nil,
        gridOverride: (columns: Int, rows: Int)? = nil,
        selectedFrames: [ActionFrameSelection]? = nil,
        source: ActionPackSource = .localImage,
        sourceMetadata: ActionPackSourceMetadata? = nil
    ) throws -> ActionPackDraft {
        let normalized = try imageNormalizer.normalize(input, targetFrameSize: targetFrameSize)
        let analysis = gridAnalyzer.analyze(normalized, targetFrameSize: targetFrameSize)

        let columns: Int
        let rows: Int
        if let override = gridOverride {
            columns = override.columns
            rows = override.rows
        } else {
            columns = analysis.columns
            rows = analysis.rows
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let slug = Self.makeSlug(from: displayName)
        let packId = "\(slug)_\(timestamp)"
        let actionId = packId
        let resourceId = "\(slug)_sheet"
        let filename = "spritesheet.png"

        let frames: [ActionFrameSelection]
        if let selected = selectedFrames {
            frames = selected
        } else {
            frames = Self.defaultFrames(columns: columns, rows: rows)
        }

        let spriteFrames = frames.map { sel in
            SpriteFrame(column: sel.column, row: sel.row, durationMs: sel.durationMs)
        }

        let resource = ActionPackResource(
            id: resourceId,
            kind: .gridImage,
            path: filename,
            frameSize: targetFrameSize,
            grid: SpriteSheetLayout(columns: columns, rows: rows)
        )

        guard let resolvedActionId = ActionId(rawValue: actionId) else {
            throw ActionPackError.invalidActionId(actionId)
        }

        let resolvedNextId = nextActionId ?? ActionId(rawValue: "idle_default")
        let action = Action(
            id: resolvedActionId,
            displayName: displayName,
            role: nil,
            assetId: resourceId,
            frames: spriteFrames,
            frameDurationMs: frameDurationMs,
            loop: loop,
            nextActionId: resolvedNextId
        )

        let manifest = ActionPackManifest(
            schemaVersion: 1,
            id: packId,
            displayName: displayName,
            createdAt: Date(),
            resources: [resource],
            actions: [action]
        )

        let previewData = try generatePreview(
            from: normalized,
            frameSize: targetFrameSize,
            columns: columns,
            rows: rows
        )

        let metadata = sourceMetadata ?? ActionPackSourceMetadata(
            source: source,
            createdAt: Date()
        )

        return ActionPackDraft(
            manifest: manifest,
            resourceImages: [filename: normalized.imageData],
            previewData: previewData,
            sourceMetadata: metadata
        )
    }

    // MARK: - Helpers

    private static func makeSlug(from name: String) -> String {
        let lowered = name
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var slug = ""
        for scalar in lowered.unicodeScalars {
            switch scalar.value {
            case 48...57, 97...122:
                slug.unicodeScalars.append(scalar)
            case 32, 45, 95:
                if !slug.hasSuffix("_") {
                    slug.append("_")
                }
            default:
                continue
            }
        }
        if slug.hasSuffix("_") {
            slug = String(slug.dropLast())
        }
        return slug.isEmpty ? "action" : String(slug.prefix(32))
    }

    private static func defaultFrames(columns: Int, rows: Int) -> [ActionFrameSelection] {
        var frames: [ActionFrameSelection] = []
        for row in 0..<rows {
            for col in 0..<columns {
                frames.append(ActionFrameSelection(column: col, row: row))
            }
        }
        return frames
    }

    private func generatePreview(
        from image: NormalizedActionImage,
        frameSize: CGSizeCodable,
        columns: Int,
        rows: Int
    ) throws -> Data? {
        guard let source = CGImageSourceCreateWithData(image.imageData as CFData, nil),
              let fullImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let fw = Int(frameSize.width)
        let fh = Int(frameSize.height)

        guard fw > 0, fh > 0, fullImage.width >= fw, fullImage.height >= fh else {
            return nil
        }

        let cropRect = CGRect(x: 0, y: 0, width: fw, height: fh)
        guard let cropped = fullImage.cropping(to: cropRect) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}
