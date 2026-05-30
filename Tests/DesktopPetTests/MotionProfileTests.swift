import Foundation
import DesktopPet

func runMotionProfileTests() {
    let tests = MotionProfileTests()
    tests.singleImageDefaultCoversAllStates()
    tests.singleImageDefaultDraggingDoesNotLoop()
    tests.profileEncodesAndDecodes()
    tests.unknownStateInDecodingThrows()
    tests.lookupFallsBackToNoneWhenStateMissing()
}

private struct MotionProfileTests {
    func singleImageDefaultCoversAllStates() {
        let profile = MotionProfileDefaults.singleImageDefault()
        for state in PetState.allCases {
            guard let motion = profile.stateMotions[state] else {
                fail("default motion profile missing state \(state.rawValue)")
            }
            expect(motion.durationMs > 0, "motion duration must be positive for state \(state.rawValue)")
            expect(motion.amplitude >= 0, "motion amplitude must be non-negative for state \(state.rawValue)")
        }
    }

    func singleImageDefaultDraggingDoesNotLoop() {
        let profile = MotionProfileDefaults.singleImageDefault()
        guard let dragging = profile.stateMotions[.dragging] else {
            fail("default profile missing dragging state")
        }
        expect(!dragging.loop, "dragging motion should not loop autonomously")

        guard let happy = profile.stateMotions[.happy] else {
            fail("default profile missing happy state")
        }
        expect(!happy.loop, "happy motion should be one-shot")
    }

    func profileEncodesAndDecodes() {
        let original = MotionProfileDefaults.singleImageDefault()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(MotionProfile.self, from: data)
            expect(decoded == original, "motion profile round-trip should preserve data")
        } catch {
            fail("motion profile round-trip failed: \(error)")
        }
    }

    func unknownStateInDecodingThrows() {
        let json = """
        {
          "stateMotions": {
            "unknown": { "kind": "bob", "amplitude": 1, "durationMs": 100, "loop": true }
          }
        }
        """
        do {
            _ = try JSONDecoder().decode(MotionProfile.self, from: Data(json.utf8))
            fail("decoding should fail for unknown pet state")
        } catch {
        }
    }

    func lookupFallsBackToNoneWhenStateMissing() {
        let profile = MotionProfile(stateMotions: [
            .idle: StateMotion(kind: .bob, amplitude: 4, durationMs: 800, loop: true)
        ])
        let walking = profile.motion(for: .walking)
        expect(walking.kind == .none, "missing state lookup should fall back to none kind")
        expect(walking.amplitude == 0, "missing state lookup should fall back to zero amplitude")
    }
}
