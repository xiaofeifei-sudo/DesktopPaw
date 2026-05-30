import AppKit
import Foundation
import DesktopPet

@MainActor
func runSingleImageRendererTests() {
    let tests = SingleImageRendererTests()
    tests.loadsAssetWhenAvailable()
    tests.fallsBackToPreviewWhenAssetMissing()
    tests.fallsBackToPlaceholderWhenAssetAndPreviewMissing()
    tests.returnsNilWhenNoResourcesAvailable()
    tests.allStatesReturnSameImage()
    tests.frameParameterIsIgnored()
}

@MainActor
private struct SingleImageRendererTests {
    func loadsAssetWhenAvailable() {
        let asset = makeImage(name: "asset")
        let preview = makeImage(name: "preview")
        let placeholder = makeImage(name: "placeholder")
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { name in
                switch name {
                case "image.png": return asset
                case "preview.png": return preview
                case PetDefinition.placeholderAssetName: return placeholder
                default: return nil
                }
            }
        )

        expect(renderer.image(for: .idle, frame: nil) === asset, "renderer should load asset when available")
    }

    func fallsBackToPreviewWhenAssetMissing() {
        let preview = makeImage(name: "preview")
        let placeholder = makeImage(name: "placeholder")
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { name in
                switch name {
                case "image.png": return nil
                case "preview.png": return preview
                case PetDefinition.placeholderAssetName: return placeholder
                default: return nil
                }
            }
        )

        expect(renderer.image(for: .idle, frame: nil) === preview, "renderer should fall back to preview when asset missing")
    }

    func fallsBackToPlaceholderWhenAssetAndPreviewMissing() {
        let placeholder = makeImage(name: "placeholder")
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { name in
                if name == PetDefinition.placeholderAssetName {
                    return placeholder
                }
                return nil
            }
        )

        expect(renderer.image(for: .idle, frame: nil) === placeholder, "renderer should fall back to placeholder when asset and preview missing")
    }

    func returnsNilWhenNoResourcesAvailable() {
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { _ in nil }
        )

        expect(renderer.image(for: .idle, frame: nil) == nil, "renderer should return nil when nothing loads")
        expect(renderer.fallbackImage() == nil, "fallback image should also be nil when nothing loads")
    }

    func allStatesReturnSameImage() {
        let asset = makeImage(name: "asset")
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { name in name == "image.png" ? asset : nil }
        )

        for state in PetState.allCases {
            expect(renderer.image(for: state, frame: nil) === asset, "single image renderer should return same image for state \(state)")
        }
    }

    func frameParameterIsIgnored() {
        let asset = makeImage(name: "asset")
        let renderer = SingleImageRenderer(
            definition: makeSingleImageDefinition(),
            imageLoader: { name in name == "image.png" ? asset : nil }
        )

        expect(
            renderer.image(for: .idle, frame: SpriteFrame(column: 5, row: 7)) === asset,
            "single image renderer should ignore frame parameter"
        )
    }
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
        id: "single-image",
        displayName: "Single",
        description: "single image",
        assetName: "image.png",
        previewAssetName: "preview.png",
        frameSize: CGSizeCodable(width: 128, height: 128),
        spritesheet: nil,
        defaultScale: 1.0,
        animations: animations,
        assetKind: .singleImage
    )
}

@MainActor
private func makeImage(name: String) -> NSImage {
    let image = NSImage(size: CGSize(width: 4, height: 4))
    image.setName(name)
    return image
}
