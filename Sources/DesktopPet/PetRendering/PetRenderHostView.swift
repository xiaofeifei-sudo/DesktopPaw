@preconcurrency import AppKit
import SwiftUI

@MainActor
public final class PetOverlayImageCache {
    public typealias Loader = @MainActor (URL) -> NSImage?

    public static let shared = PetOverlayImageCache()

    private let loader: Loader
    private var cachedURL: URL?
    private var cachedImage: NSImage?

    public init(loader: @escaping Loader = { NSImage(contentsOf: $0) }) {
        self.loader = loader
    }

    public func image(for url: URL) -> NSImage? {
        if cachedURL == url {
            return cachedImage
        }

        let image = loader(url)
        cachedURL = url
        cachedImage = image
        return image
    }

    public func clear() {
        cachedURL = nil
        cachedImage = nil
    }
}

@MainActor
public struct PetRenderHostView: View {
    private let renderer: PetRenderable
    private let state: PetState
    private let frame: SpriteFrame?
    private let renderSize: CGSize
    private let motionValue: MotionValue
    private let visualOverlay: PetVisualOverlayState?
    private let reducedMotion: Bool
    private let overlayImageCache: PetOverlayImageCache

    public init(
        renderer: PetRenderable,
        state: PetState,
        frame: SpriteFrame?,
        renderSize: CGSize,
        motionValue: MotionValue = .identity,
        visualOverlay: PetVisualOverlayState? = nil,
        reducedMotion: Bool = false,
        overlayImageCache: PetOverlayImageCache = .shared
    ) {
        self.renderer = renderer
        self.state = state
        self.frame = frame
        self.renderSize = renderSize
        self.motionValue = motionValue
        self.visualOverlay = visualOverlay
        self.reducedMotion = reducedMotion
        self.overlayImageCache = overlayImageCache
    }

    public var body: some View {
        ZStack {
            basePetImage
                .opacity(baseImageOpacity)

            if let overlay = visualOverlay {
                overlayImage(for: overlay)
            }
        }
        .frame(width: renderSize.width, height: renderSize.height)
        .petMotionEffect(motionValue)
    }

    @ViewBuilder
    private var basePetImage: some View {
        if let image = renderer.image(for: state, frame: frame) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else if let image = renderer.fallbackImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }

    private var baseImageOpacity: Double {
        switch visualOverlay?.renderMode {
        case .replaceWholeImage: 0
        case .overlayImage: 1
        case nil: 1
        }
    }

    @ViewBuilder
    private func overlayImage(for overlay: PetVisualOverlayState) -> some View {
        if let nsImage = overlayImageCache.image(for: overlay.imageURL) {
            switch overlay.renderMode {
            case .replaceWholeImage:
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .transition(reducedMotion ? .identity : .opacity)
                    .animation(reducedMotion ? nil : .easeIn(duration: 0.4), value: overlay.id)

            case .overlayImage:
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .transition(reducedMotion ? .identity : .opacity)
                    .animation(reducedMotion ? nil : .easeIn(duration: 0.4), value: overlay.id)
            }
        }
    }
}
