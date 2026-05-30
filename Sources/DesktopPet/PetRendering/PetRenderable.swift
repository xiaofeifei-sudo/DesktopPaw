@preconcurrency import AppKit
import Foundation

@MainActor
public protocol PetRenderable: AnyObject {
    var definition: PetDefinition { get }

    func image(for state: PetState, frame: SpriteFrame?) -> NSImage?
    func fallbackImage() -> NSImage?
}
