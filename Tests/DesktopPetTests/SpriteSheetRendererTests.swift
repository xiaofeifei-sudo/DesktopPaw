import AppKit
import Foundation
import ImageIO
import DesktopPet

@MainActor
func runSpriteSheetRendererTests() {
    let tests = SpriteSheetRendererTests()
    tests.transparentTrailingFrameFallsBackToNearestVisibleFrame()
}

@MainActor
private struct SpriteSheetRendererTests {
    func transparentTrailingFrameFallsBackToNearestVisibleFrame() {
        let definition = PetDefinition(
            id: "transparent-frame-pet",
            displayName: "Transparent Frame",
            description: "transparent frame test",
            assetName: "spritesheet.png",
            previewAssetName: nil,
            frameSize: CGSizeCodable(width: 2, height: 2),
            spritesheet: SpriteSheetLayout(columns: 2, rows: 1),
            defaultScale: 1.0,
            catalog: makeCatalog(),
            assetKind: .spriteSheet
        )
        let image = makeImageWithTransparentSecondFrame()
        let renderer = SpriteSheetRenderer(definition: definition, imageLoader: { name in
            name == "spritesheet.png" ? image : nil
        })

        let rendered = renderer.image(for: SpriteFrame(column: 1, row: 0))

        expect(rendered != nil, "transparent trailing frame should render a fallback frame")
        expect(hasVisiblePixels(rendered), "transparent trailing frame should fall back to a visible frame")
    }

    private func makeCatalog() -> PetActionCatalog {
        let actions = ActionRole.allCases.map { role in
            Action(
                id: ActionId(rawValue: "\(role.rawValue)_default")!,
                displayName: role.rawValue,
                role: role,
                tags: [],
                frames: [SpriteFrame(column: 0, row: 0), SpriteFrame(column: 1, row: 0)],
                frameDurationMs: 160,
                loop: true
            )
        }
        return PetActionCatalog(petId: "transparent-frame-pet", actions: actions, warnings: [])
    }

    private func makeImageWithTransparentSecondFrame() -> NSImage {
        guard let context = CGContext(
            data: nil,
            width: 4,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fail("could not create renderer test context")
        }

        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))

        guard let image = context.makeImage() else {
            fail("could not create renderer test image")
        }
        return NSImage(cgImage: image, size: CGSize(width: 4, height: 2))
    }

    private func hasVisiblePixels(_ image: NSImage?) -> Bool {
        guard let image,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return false
        }

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
                    return true
                }
            }
        }
        return false
    }
}
