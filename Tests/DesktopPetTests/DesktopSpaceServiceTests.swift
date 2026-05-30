import Foundation
import DesktopPet

func runDesktopSpaceServiceTests() {
    func testDefaultServiceIsNotRunning() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        expect(!service.isEnabled, "default service should not be running")
        expect(service.activityZones.isEmpty, "default zones should be empty")
        expect(!service.isMovementConstrained, "default movement should not be constrained")
    }

    func testStartAndStopService() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        service.start()
        expect(service.isEnabled, "service should be running after start")

        service.stop()
        expect(!service.isEnabled, "service should not be running after stop")
    }

    func testDoubleStartIsNoop() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        service.start()
        service.start()
        expect(service.isEnabled, "double start should keep service running")
        service.stop()
    }

    func testStopWhenNotRunningIsNoop() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        service.stop()
        expect(!service.isEnabled, "stop when not running should noop")
    }

    func testSetActivityZones() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        let zones = [
            ActivityZone(id: "z1", rect: CGRect(x: 0, y: 0, width: 100, height: 100)),
            ActivityZone(id: "z2", rect: CGRect(x: 200, y: 200, width: 300, height: 300))
        ]
        service.setActivityZones(zones)
        expect(service.activityZones.count == 2, "should have 2 activity zones")
        expect(service.activityZones[0].id == "z1", "first zone should be z1")
        expect(service.activityZones[1].id == "z2", "second zone should be z2")
    }

    func testSetMovementConstrained() {
        let service = DesktopSpaceService(petPositionProvider: { .zero })
        expect(!service.isMovementConstrained, "should start unconstrained")

        service.setMovementConstrained(true)
        expect(service.isMovementConstrained, "should be constrained after setting true")

        service.setMovementConstrained(false)
        expect(!service.isMovementConstrained, "should be unconstrained after setting false")
    }

    func testSuggestionCallbackFires() {
        let expectation = ExpectationHelper()
        let service = DesktopSpaceService(
            engine: SpatialBehaviorEngine(
                screenDetector: ScreenBoundaryDetector(edgeThreshold: 40),
                windowDetector: WindowProximityDetector(proximityThreshold: 30)
            ),
            pollInterval: 0.1,
            petPositionProvider: { CGPoint(x: 960, y: 540) }
        )
        service.onSuggestion = { _ in
            expectation.fulfill()
        }

        service.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        service.stop()

        expect(expectation.wasFulfilled, "suggestion callback should fire during polling")
    }

    func testSuggestionNotFiredAfterStop() {
        let expectation = ExpectationHelper()
        let service = DesktopSpaceService(
            pollInterval: 0.1,
            petPositionProvider: { .zero }
        )
        service.onSuggestion = { _ in
            expectation.fulfill()
        }

        service.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        service.stop()
        expectation.reset()

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        expect(!expectation.wasFulfilled, "suggestion callback should not fire after stop")
    }

    testDefaultServiceIsNotRunning()
    testStartAndStopService()
    testDoubleStartIsNoop()
    testStopWhenNotRunningIsNoop()
    testSetActivityZones()
    testSetMovementConstrained()
    testSuggestionCallbackFires()
    testSuggestionNotFiredAfterStop()
}
