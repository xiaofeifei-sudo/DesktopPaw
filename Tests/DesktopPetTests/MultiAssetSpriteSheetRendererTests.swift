import AppKit
import Foundation
import ImageIO
import DesktopPet

@MainActor
func runMultiAssetSpriteSheetRendererTests() {
    let tests = MultiAssetSpriteSheetRendererTests()
    tests.resolveNilReturnsDefaultAsset()
    tests.gridImageCropsFrame()
    tests.perFrameAssetIdSelection()
    tests.fallbackToPreview()
    tests.fallbackToAssetPreviewUsesInjectedLoaderOnce()
    tests.fallbackToPlaceholder()
    tests.singleImageAssetDirectRender()
}

@MainActor
private struct MultiAssetSpriteSheetRendererTests {

    func resolveNilReturnsDefaultAsset() {
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .gridImage,
                    relativePath: "spritesheet.png",
                    frameSize: CGSizeCodable(width: 64, height: 64),
                    grid: SpriteSheetLayout(columns: 4, rows: 1)
                )
            ]
        )

        let resolved = library.resolve(nil)
        expect(resolved?.id == "base/default", "resolve(nil) should return default asset")
    }

    func gridImageCropsFrame() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let image = makeTestImage(width: 256, height: 64)
        let definition = makeDefinition(frameSize: frameSize, spritesheet: SpriteSheetLayout(columns: 4, rows: 1))
        let library = makeLibrary(frameSize: frameSize)

        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                name == "spritesheet.png" ? image : nil
            }
        )

        let frame = SpriteFrame(column: 1, row: 0)
        let result = renderer.image(for: frame)
        expect(result != nil, "grid image crop should return an image")
    }

    func perFrameAssetIdSelection() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let baseImage = makeTestImage(width: 256, height: 64, red: 1.0)
        let packImage = makeTestImage(width: 256, height: 64, red: 0.0)
        let definition = makeDefinition(
            frameSize: frameSize,
            spritesheet: SpriteSheetLayout(columns: 4, rows: 1)
        )
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .gridImage,
                    relativePath: "spritesheet.png",
                    frameSize: frameSize,
                    grid: SpriteSheetLayout(columns: 4, rows: 1)
                ),
                "wave_pack/sheet": PetRenderAsset(
                    id: "wave_pack/sheet",
                    kind: .gridImage,
                    relativePath: "action-packs/wave_pack/sheet.png",
                    frameSize: frameSize,
                    grid: SpriteSheetLayout(columns: 4, rows: 1)
                )
            ]
        )

        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                if name == "spritesheet.png" { return baseImage }
                if name == "action-packs/wave_pack/sheet.png" { return packImage }
                return nil
            }
        )

        let baseFrame = SpriteFrame(column: 0, row: 0)
        let baseResult = renderer.image(for: baseFrame)
        expect(baseResult != nil, "base frame should render")

        let packFrame = SpriteFrame(assetId: "wave_pack/sheet", column: 0, row: 0)
        let packResult = renderer.image(for: packFrame)
        expect(packResult != nil, "pack frame should render")
    }

    func fallbackToPreview() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let previewImage = makeTestImage(width: 64, height: 64)
        let definition = PetDefinition(
            id: "test-pet",
            displayName: "Test",
            description: "test",
            assetName: "spritesheet.png",
            previewAssetName: "preview.png",
            frameSize: frameSize,
            spritesheet: SpriteSheetLayout(columns: 4, rows: 1),
            defaultScale: 1.0,
            catalog: makeCatalog(),
            assetKind: .spriteSheet
        )
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .gridImage,
                    relativePath: "spritesheet.png",
                    frameSize: frameSize,
                    grid: SpriteSheetLayout(columns: 4, rows: 1),
                    previewRelativePath: "preview.png"
                )
            ]
        )

        // Don't provide spritesheet.png, so it falls back
        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                name == "preview.png" ? previewImage : nil
            }
        )

        let result = renderer.fallbackImage()
        expect(result != nil, "should fall back to preview")
    }

    func fallbackToAssetPreviewUsesInjectedLoaderOnce() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let assetPreviewImage = makeTestImage(width: 64, height: 64)
        var requestedNames: [String] = []
        let definition = PetDefinition(
            id: "test-pet",
            displayName: "Test",
            description: "test",
            assetName: "spritesheet.png",
            previewAssetName: nil,
            frameSize: frameSize,
            spritesheet: SpriteSheetLayout(columns: 4, rows: 1),
            defaultScale: 1.0,
            catalog: makeCatalog(),
            assetKind: .spriteSheet
        )
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .gridImage,
                    relativePath: "missing-spritesheet.png",
                    frameSize: frameSize,
                    grid: SpriteSheetLayout(columns: 4, rows: 1),
                    previewRelativePath: "asset-preview.png"
                )
            ]
        )

        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                requestedNames.append(name)
                return name == "asset-preview.png" ? assetPreviewImage : nil
            }
        )

        let first = renderer.fallbackImage()
        let second = renderer.fallbackImage()

        expect(first === assetPreviewImage, "asset preview fallback should use the injected loader")
        expect(second === assetPreviewImage, "asset preview fallback should return the cached image")
        expect(
            requestedNames.filter { $0 == "asset-preview.png" }.count == 1,
            "asset preview should load once, got requests: \(requestedNames)"
        )
    }

    func fallbackToPlaceholder() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let placeholderImage = makeTestImage(width: 64, height: 64)
        let definition = PetDefinition(
            id: "test-pet",
            displayName: "Test",
            description: "test",
            assetName: "spritesheet.png",
            previewAssetName: nil,
            frameSize: frameSize,
            spritesheet: SpriteSheetLayout(columns: 4, rows: 1),
            defaultScale: 1.0,
            catalog: makeCatalog(),
            assetKind: .spriteSheet
        )
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .gridImage,
                    relativePath: "spritesheet.png",
                    frameSize: frameSize,
                    grid: SpriteSheetLayout(columns: 4, rows: 1)
                )
            ]
        )

        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                name == PetDefinition.placeholderAssetName ? placeholderImage : nil
            }
        )

        let result = renderer.fallbackImage()
        expect(result != nil, "should fall back to placeholder")
    }

    func singleImageAssetDirectRender() {
        let frameSize = CGSizeCodable(width: 64, height: 64)
        let wholeImage = makeTestImage(width: 64, height: 64)
        let definition = PetDefinition(
            id: "test-pet",
            displayName: "Test",
            description: "test",
            assetName: "image.png",
            previewAssetName: nil,
            frameSize: frameSize,
            defaultScale: 1.0,
            catalog: makeCatalog(),
            assetKind: .singleImage
        )
        let library = PetRenderAssetLibrary(
            defaultAssetId: "base/default",
            assetsById: [
                "base/default": PetRenderAsset(
                    id: "base/default",
                    kind: .wholeImage,
                    relativePath: "image.png",
                    frameSize: frameSize
                )
            ]
        )

        let renderer = MultiAssetSpriteSheetRenderer(
            definition: definition,
            assetLibrary: library,
            imageLoader: { name in
                name == "image.png" ? wholeImage : nil
            }
        )

        let frame = SpriteFrame(column: 0, row: 0)
        let result = renderer.image(for: frame)
        expect(result != nil, "whole image should render")
    }
}

// MARK: - Helpers

@MainActor
private func makeDefinition(
    frameSize: CGSizeCodable,
    spritesheet: SpriteSheetLayout? = nil
) -> PetDefinition {
    PetDefinition(
        id: "test-pet",
        displayName: "Test",
        description: "test",
        assetName: "spritesheet.png",
        previewAssetName: "preview.png",
        frameSize: frameSize,
        spritesheet: spritesheet,
        defaultScale: 1.0,
        catalog: makeCatalog(),
        assetKind: .spriteSheet
    )
}

@MainActor
private func makeCatalog() -> PetActionCatalog {
    PetActionCatalog(
        petId: "test-pet",
        actions: [
            Action(
                id: ActionId(rawValue: "idle_default")!,
                displayName: "Idle",
                role: .idle,
                frames: [SpriteFrame(column: 0, row: 0)],
                frameDurationMs: 160,
                loop: true
            )
        ],
        warnings: []
    )
}

@MainActor
private func makeLibrary(frameSize: CGSizeCodable) -> PetRenderAssetLibrary {
    PetRenderAssetLibrary(
        defaultAssetId: "base/default",
        assetsById: [
            "base/default": PetRenderAsset(
                id: "base/default",
                kind: .gridImage,
                relativePath: "spritesheet.png",
                frameSize: frameSize,
                grid: SpriteSheetLayout(columns: 4, rows: 1)
            )
        ]
    )
}

@MainActor
private func makeTestImage(width: Int, height: Int, red: CGFloat = 1.0) -> NSImage {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return NSImage(size: NSSize(width: width, height: height))
    }
    context.setFillColor(CGColor(red: red, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else {
        return NSImage(size: NSSize(width: width, height: height))
    }
    return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
}
