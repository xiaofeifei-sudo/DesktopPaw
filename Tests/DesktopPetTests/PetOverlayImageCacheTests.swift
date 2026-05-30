import AppKit
import DesktopPet
import Foundation

@MainActor
func runPetOverlayImageCacheTests() {
    let tests = PetOverlayImageCacheTests()
    tests.sameURLUsesCachedImage()
    tests.differentURLReloadsImage()
}

@MainActor
private struct PetOverlayImageCacheTests {
    func sameURLUsesCachedImage() {
        let url = URL(fileURLWithPath: "/tmp/overlay-a.png")
        let image = NSImage(size: NSSize(width: 8, height: 8))
        var loadCount = 0
        let cache = PetOverlayImageCache { requestedURL in
            expect(requestedURL == url, "loader should receive the requested URL")
            loadCount += 1
            return image
        }

        let first = cache.image(for: url)
        let second = cache.image(for: url)

        expect(first === image, "first load should return loader image")
        expect(second === image, "second load should return cached image")
        expect(loadCount == 1, "same overlay URL should load once, got \(loadCount)")
    }

    func differentURLReloadsImage() {
        let firstURL = URL(fileURLWithPath: "/tmp/overlay-a.png")
        let secondURL = URL(fileURLWithPath: "/tmp/overlay-b.png")
        let firstImage = NSImage(size: NSSize(width: 8, height: 8))
        let secondImage = NSImage(size: NSSize(width: 10, height: 10))
        var requestedURLs: [URL] = []
        let cache = PetOverlayImageCache { url in
            requestedURLs.append(url)
            return url == firstURL ? firstImage : secondImage
        }

        _ = cache.image(for: firstURL)
        let reloaded = cache.image(for: secondURL)

        expect(reloaded === secondImage, "new overlay URL should return reloaded image")
        expect(requestedURLs == [firstURL, secondURL], "cache should reload when overlay URL changes")
    }
}
