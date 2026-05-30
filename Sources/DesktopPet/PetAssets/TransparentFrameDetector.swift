import CoreGraphics
import Foundation

extension CGImage {
    func desktopPetFrameIsFullyTransparent(_ rect: CGRect) -> Bool {
        guard desktopPetHasAlpha else {
            return false
        }
        guard let cropped = cropping(to: rect) else {
            return false
        }
        return cropped.desktopPetIsFullyTransparent()
    }

    var desktopPetHasAlpha: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private func desktopPetIsFullyTransparent() -> Bool {
        let width = self.width
        let height = self.height
        guard width > 0, height > 0 else {
            return true
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .none
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else {
            return false
        }

        var alphaIndex = bytesPerPixel - 1
        while alphaIndex < pixels.count {
            if pixels[alphaIndex] != 0 {
                return false
            }
            alphaIndex += bytesPerPixel
        }
        return true
    }
}
