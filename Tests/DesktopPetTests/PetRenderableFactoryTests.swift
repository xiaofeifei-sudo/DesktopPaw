import AppKit
import Foundation
import DesktopPet

@MainActor
func runPetRenderableFactoryTests() {
    let tests = PetRenderableFactoryTests()
    tests.spriteSheetDefinitionProducesSpriteSheetRenderer()
    tests.singleImageDefinitionProducesSingleImageRenderer()
    tests.imageLoaderWithoutFolderUsesBundledLoader()
    tests.imageLoaderPrefersFolderAssetWhenAvailable()
    tests.imageLoaderFallsBackToBundledWhenFolderMissesAsset()
}

@MainActor
private struct PetRenderableFactoryTests {
    func spriteSheetDefinitionProducesSpriteSheetRenderer() {
        let factory = DefaultPetRenderableFactory()
        let renderer = factory.makeRenderer(for: makeSpriteSheetDefinition(), folderURL: nil)

        expect(renderer is SpriteSheetRenderer, "factory should return SpriteSheetRenderer for sprite-sheet assetKind")
        expect(renderer.definition.assetKind == .spriteSheet, "renderer definition should reflect sprite-sheet kind")
    }

    func singleImageDefinitionProducesSingleImageRenderer() {
        let factory = DefaultPetRenderableFactory()
        let renderer = factory.makeRenderer(for: makeSingleImageDefinition(), folderURL: nil)

        expect(renderer is SingleImageRenderer, "factory should return SingleImageRenderer for single-image assetKind")
        expect(renderer.definition.assetKind == .singleImage, "renderer definition should reflect single-image kind")
    }

    func imageLoaderWithoutFolderUsesBundledLoader() {
        let loader = DefaultPetRenderableFactory.makeImageLoader(folderURL: nil)
        let result = loader("definitely-missing-asset-\(UUID().uuidString).png")

        expect(result == nil, "loader without folder should defer to bundled lookup, returning nil for unknown assets")
    }

    func imageLoaderPrefersFolderAssetWhenAvailable() {
        let folderURL = makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let assetURL = folderURL.appendingPathComponent("custom-pet.png")
        let pngData = makePNGData(width: 4, height: 4)
        try? pngData.write(to: assetURL)

        let loader = DefaultPetRenderableFactory.makeImageLoader(folderURL: folderURL)
        let result = loader("custom-pet.png")

        expect(result != nil, "loader should load asset directly from folder when present")
    }

    func imageLoaderFallsBackToBundledWhenFolderMissesAsset() {
        let folderURL = makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let loader = DefaultPetRenderableFactory.makeImageLoader(folderURL: folderURL)
        let result = loader("definitely-missing-asset-\(UUID().uuidString).png")

        expect(result == nil, "loader should fall back to bundled lookup when folder file is missing")
    }
}

@MainActor
private func makeSpriteSheetDefinition() -> PetDefinition {
    var animations: [PetState: AnimationClip] = [:]
    for state in PetState.allCases {
        animations[state] = AnimationClip(
            state: state,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 1_000,
            loop: true
        )
    }

    return PetDefinition(
        id: "sheet-pet",
        displayName: "Sheet",
        description: "sprite sheet pet",
        assetName: "sheet.png",
        previewAssetName: "preview.png",
        frameSize: CGSizeCodable(width: 64, height: 64),
        spritesheet: SpriteSheetLayout(columns: 1, rows: 1),
        defaultScale: 1.0,
        animations: animations,
        assetKind: .spriteSheet
    )
}

@MainActor
private func makeSingleImageDefinition() -> PetDefinition {
    var animations: [PetState: AnimationClip] = [:]
    for state in PetState.allCases {
        animations[state] = AnimationClip(
            state: state,
            frames: [SpriteFrame(column: 0, row: 0)],
            frameDurationMs: 1_000,
            loop: true
        )
    }

    return PetDefinition(
        id: "single-pet",
        displayName: "Single",
        description: "single image pet",
        assetName: "image.png",
        previewAssetName: nil,
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: nil,
        defaultScale: 1.0,
        animations: animations,
        assetKind: .singleImage
    )
}

@MainActor
private func makeTemporaryFolder() -> URL {
    let folderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesktopPetFactoryTests")
        .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    return folderURL
}

@MainActor
private func makePNGData(width: Int, height: Int) -> Data {
    let image = NSImage(size: CGSize(width: width, height: height))
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fail("failed to create PNG data for factory tests")
    }
    return pngData
}
