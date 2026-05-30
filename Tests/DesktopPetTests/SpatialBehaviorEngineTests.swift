import Foundation
import DesktopPet

func runSpatialBehaviorEngineTests() {
    let screenDetector = ScreenBoundaryDetector(edgeThreshold: 40)
    let windowDetector = WindowProximityDetector(proximityThreshold: 30)
    let engine = SpatialBehaviorEngine(
        screenDetector: screenDetector,
        windowDetector: windowDetector
    )

    func testSuggestFreeRoamInCenterOfScreen() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 960, y: 540))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        expect(suggestion == .freeRoam, "center of screen should suggest freeRoam: got \(suggestion)")
    }

    func testSuggestLookTowardAtTopEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 960, y: 1070))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        if case .lookToward(let direction) = suggestion {
            expect(direction == .bottom, "near top edge should look toward bottom")
        } else {
            fail("expected lookToward, got \(suggestion)")
        }
    }

    func testSuggestSitOnEdgeNearWindow() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let window = WindowProximityDetector.WindowInfo(
            bounds: CGRect(x: 500, y: 300, width: 800, height: 600)
        )
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [window])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 900, y: 895))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        if case .sitOnEdge(let edge) = suggestion {
            expect(edge == .top, "near window top edge should suggest sitOnEdge top: got \(edge)")
        } else {
            fail("expected sitOnEdge, got \(suggestion)")
        }
    }

    func testSuggestFreeRoamWhenDragging() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 960, y: 1070), isDragging: true)
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        expect(suggestion == .freeRoam, "dragging should suggest freeRoam regardless of position: got \(suggestion)")
    }

    func testSuggestConstrainedToZone() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let zone = ActivityZone(id: "z1", rect: CGRect(x: 100, y: 100, width: 500, height: 500))
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 300, y: 300))

        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [zone])
        if case .constrainedToZone(let z) = suggestion {
            expect(z.id == "z1", "should be constrained to zone z1")
        } else {
            fail("expected constrainedToZone, got \(suggestion)")
        }
    }

    func testSuggestLookTowardAtBottomEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 960, y: 10))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        if case .lookToward(let direction) = suggestion {
            expect(direction == .top, "near bottom edge should look toward top")
        } else {
            fail("expected lookToward, got \(suggestion)")
        }
    }

    func testSuggestLookTowardAtLeftEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 10, y: 540))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        if case .lookToward(let direction) = suggestion {
            expect(direction == .right, "near left edge should look toward right")
        } else {
            fail("expected lookToward, got \(suggestion)")
        }
    }

    func testSuggestLookTowardAtRightEdge() {
        let screens = [
            ScreenBoundaryDetector.ScreenInfo(
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        ]
        let env = SpatialBehaviorEngine.Environment(screens: screens, windows: [])
        let pet = SpatialBehaviorEngine.PetState(position: CGPoint(x: 1910, y: 540))
        let suggestion = engine.suggest(pet: pet, environment: env, activityZones: [])
        if case .lookToward(let direction) = suggestion {
            expect(direction == .left, "near right edge should look toward left")
        } else {
            fail("expected lookToward, got \(suggestion)")
        }
    }

    testSuggestFreeRoamInCenterOfScreen()
    testSuggestLookTowardAtTopEdge()
    testSuggestSitOnEdgeNearWindow()
    testSuggestFreeRoamWhenDragging()
    testSuggestConstrainedToZone()
    testSuggestLookTowardAtBottomEdge()
    testSuggestLookTowardAtLeftEdge()
    testSuggestLookTowardAtRightEdge()
}
