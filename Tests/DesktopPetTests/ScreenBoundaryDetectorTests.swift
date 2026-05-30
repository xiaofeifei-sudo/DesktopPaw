import Foundation
import DesktopPet

func runScreenBoundaryDetectorTests() {
    let detector = ScreenBoundaryDetector(edgeThreshold: 40)

    func testNearTopEdgeDetected() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 960, y: 1070)
        let edge = detector.isNearScreenEdge(point, screens: screens)
        expect(edge == .top, "point near top edge should detect top: got \(String(describing: edge))")
    }

    func testNearBottomEdgeDetected() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 960, y: 10)
        let edge = detector.isNearScreenEdge(point, screens: screens)
        expect(edge == .bottom, "point near bottom edge should detect bottom: got \(String(describing: edge))")
    }

    func testNearLeftEdgeDetected() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 10, y: 540)
        let edge = detector.isNearScreenEdge(point, screens: screens)
        expect(edge == .left, "point near left edge should detect left: got \(String(describing: edge))")
    }

    func testNearRightEdgeDetected() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 1910, y: 540)
        let edge = detector.isNearScreenEdge(point, screens: screens)
        expect(edge == .right, "point near right edge should detect right: got \(String(describing: edge))")
    }

    func testCenterPointNotNearEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 960, y: 540)
        let edge = detector.isNearScreenEdge(point, screens: screens)
        expect(edge == nil, "center point should not be near any edge: got \(String(describing: edge))")
    }

    func testNearestScreenEdgeReturnsCorrectEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let point = CGPoint(x: 960, y: 1070)
        let result = detector.nearestScreenEdge(for: point, screens: screens)
        expect(result?.edge == .top, "nearest edge to top point should be top")
        expect(result?.distance ?? 0 <= 40, "distance should be within threshold")
    }

    func testContainingScreenFindsCorrectScreen() {
        let screen1 = ScreenBoundaryDetector.ScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let screen2 = ScreenBoundaryDetector.ScreenInfo(
            frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        )
        let screens = [screen1, screen2]

        let point1 = CGPoint(x: 500, y: 500)
        let found1 = detector.containingScreen(for: point1, screens: screens)
        expect(found1?.frame == screen1.frame, "point on screen 1 should find screen 1")

        let point2 = CGPoint(x: 2500, y: 500)
        let found2 = detector.containingScreen(for: point2, screens: screens)
        expect(found2?.frame == screen2.frame, "point on screen 2 should find screen 2")

        let point3 = CGPoint(x: -100, y: 500)
        let found3 = detector.containingScreen(for: point3, screens: screens)
        expect(found3 == nil, "point outside all screens should return nil")
    }

    func testEmptyScreensReturnsNil() {
        let point = CGPoint(x: 500, y: 500)
        let edge = detector.isNearScreenEdge(point, screens: [])
        expect(edge == nil, "empty screens should return nil edge")
    }

    testNearTopEdgeDetected()
    testNearBottomEdgeDetected()
    testNearLeftEdgeDetected()
    testNearRightEdgeDetected()
    testCenterPointNotNearEdge()
    testNearestScreenEdgeReturnsCorrectEdge()
    testContainingScreenFindsCorrectScreen()
    testEmptyScreensReturnsNil()
}
