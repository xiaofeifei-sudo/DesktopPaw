@preconcurrency import AppKit
import Foundation

@MainActor
public final class SingleImageRenderer: PetRenderable {
    public typealias ImageLoader = @MainActor (String) -> NSImage?

    public let definition: PetDefinition

    private let resolvedImage: NSImage?

    public init(
        definition: PetDefinition,
        imageLoader: ImageLoader = SpriteSheetRenderer.loadBundledImage(named:)
    ) {
        self.definition = definition

        if let image = imageLoader(definition.assetName) {
            self.resolvedImage = image
        } else if let previewAssetName = definition.previewAssetName,
                  let preview = imageLoader(previewAssetName) {
            DesktopPetLog.assets.warning(
                "Single image asset unavailable for \(definition.id, privacy: .public); using preview fallback."
            )
            self.resolvedImage = preview
        } else if let placeholder = imageLoader(PetDefinition.placeholderAssetName) {
            DesktopPetLog.assets.warning(
                "Single image preview unavailable for \(definition.id, privacy: .public); using placeholder fallback."
            )
            self.resolvedImage = placeholder
        } else {
            DesktopPetLog.assets.error(
                "Pet resources unavailable for \(definition.id, privacy: .public), including placeholder."
            )
            self.resolvedImage = nil
        }
    }

    public func image(for state: PetState, frame: SpriteFrame?) -> NSImage? {
        resolvedImage
    }

    public func fallbackImage() -> NSImage? {
        resolvedImage
    }
}
