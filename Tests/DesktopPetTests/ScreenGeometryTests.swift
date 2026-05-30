import CoreGraphics
import DesktopPet

func runScreenGeometryTests() {
    let tests = ScreenGeometryTests()
    tests.offscreenFrameUsesDefaultFrameOnStartup()
    tests.visibleFrameRemainsInsideScreen()
    tests.overflowingFrameIsClamped()
    tests.multiDisplayCoordinatesSelectContainingDisplay()
}

private struct ScreenGeometryTests {
    func offscreenFrameUsesDefaultFrameOnStartup() {
        let geometry = ScreenGeometry(visibleFrames: [mainDisplay])

        let frame = geometry.startupFrame(
            savedFrame: CGRect(x: 2_500, y: 1_600, width: 128, height: 128),
            frameSize: petSize
        )

        expect(frame == CGRect(x: 1_288, y: 24, width: 128, height: 128), "offscreen startup frame should use default")
    }

    func visibleFrameRemainsInsideScreen() {
        let geometry = ScreenGeometry(visibleFrames: [mainDisplay])
        let saved = CGRect(x: 100, y: 100, width: 128, height: 128)

        expect(geometry.startupFrame(savedFrame: saved, frameSize: petSize) == saved, "visible saved frame should be preserved")
    }

    func overflowingFrameIsClamped() {
        let geometry = ScreenGeometry(visibleFrames: [mainDisplay])

        let frame = geometry.clamp(frame: CGRect(x: 1_400, y: -50, width: 128, height: 128))

        expect(frame == CGRect(x: 1_312, y: 0, width: 128, height: 128), "overflowing frame should clamp inside visible bounds")
    }

    func multiDisplayCoordinatesSelectContainingDisplay() {
        let secondary = CGRect(x: -1_280, y: 0, width: 1_280, height: 800)
        let geometry = ScreenGeometry(visibleFrames: [mainDisplay, secondary])

        expect(geometry.visibleFrame(containing: CGPoint(x: -400, y: 300)) == secondary, "point should resolve to secondary display")
        expect(
            geometry.clamp(frame: CGRect(x: -100, y: 760, width: 128, height: 128))
                == CGRect(x: -128, y: 672, width: 128, height: 128),
            "clamp should target the display containing the frame center"
        )
    }

    private let mainDisplay = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    private let petSize = CGSize(width: 128, height: 128)
}
