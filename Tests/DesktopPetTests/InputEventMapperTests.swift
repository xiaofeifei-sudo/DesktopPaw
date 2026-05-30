import Foundation
import DesktopPet

func runInputEventMapperTests() {
    let mapper = InputEventMapper()
    let now = Date()

    func testExpressiveKeyboardTriggersWithOneEvent() {
        let result = mapper.classify(keyboardCount: 1, mouseCount: 0, intensity: .expressive, now: now)
        expect(result.keyboardActive, "expressive: 1 keyDown should trigger keyboard activity")
        expect(!result.mouseActive, "expressive: no mouse events should not trigger mouse activity")
    }

    func testExpressiveKeyboardDoesNotTriggerWithZero() {
        let result = mapper.classify(keyboardCount: 0, mouseCount: 0, intensity: .expressive, now: now)
        expect(!result.keyboardActive, "expressive: 0 keyDown events should not trigger keyboard activity")
        expect(!result.mouseActive, "expressive: 0 mouse events should not trigger mouse activity")
    }

    func testModerateKeyboardRequiresTwoEvents() {
        let low = mapper.classify(keyboardCount: 1, mouseCount: 0, intensity: .moderate, now: now)
        expect(!low.keyboardActive, "moderate: 1 keyDown should not trigger keyboard activity")

        let high = mapper.classify(keyboardCount: 2, mouseCount: 0, intensity: .moderate, now: now)
        expect(high.keyboardActive, "moderate: 2 keyDown events should trigger keyboard activity")
    }

    func testSubtleKeyboardRequiresFourEvents() {
        let low = mapper.classify(keyboardCount: 3, mouseCount: 0, intensity: .subtle, now: now)
        expect(!low.keyboardActive, "subtle: 3 keyDown events should not trigger keyboard activity")

        let high = mapper.classify(keyboardCount: 4, mouseCount: 0, intensity: .subtle, now: now)
        expect(high.keyboardActive, "subtle: 4 keyDown events should trigger keyboard activity")
    }

    func testExpressiveMouseTriggersWithFiveEvents() {
        let result = mapper.classify(keyboardCount: 0, mouseCount: 5, intensity: .expressive, now: now)
        expect(result.mouseActive, "expressive: 5 mouse events should trigger mouse activity")
        expect(!result.keyboardActive, "expressive: no keyboard should not trigger keyboard activity")
    }

    func testModerateMouseRequiresFifteenEvents() {
        let low = mapper.classify(keyboardCount: 0, mouseCount: 14, intensity: .moderate, now: now)
        expect(!low.mouseActive, "moderate: 14 mouse events should not trigger mouse activity")

        let high = mapper.classify(keyboardCount: 0, mouseCount: 15, intensity: .moderate, now: now)
        expect(high.mouseActive, "moderate: 15 mouse events should trigger mouse activity")
    }

    func testSubtleMouseRequiresFortyEvents() {
        let low = mapper.classify(keyboardCount: 0, mouseCount: 39, intensity: .subtle, now: now)
        expect(!low.mouseActive, "subtle: 39 mouse events should not trigger mouse activity")

        let high = mapper.classify(keyboardCount: 0, mouseCount: 40, intensity: .subtle, now: now)
        expect(high.mouseActive, "subtle: 40 mouse events should trigger mouse activity")
    }

    func testEdgeChangeKeyboardBecameActive() {
        let prev: InputEventMapper.RhythmResult = .init(keyboardActive: false, mouseActive: false, isIdle: true)
        let curr: InputEventMapper.RhythmResult = .init(keyboardActive: true, mouseActive: false, isIdle: false)
        let edge = mapper.edgeChange(current: curr, previous: prev)
        expect(edge.keyboardBecameActive, "keyboard should become active when transitioning from inactive")
        expect(!edge.mouseBecameActive, "mouse should not become active when only keyboard changed")
        expect(!edge.becameIdle, "should not become idle when keyboard is active")
    }

    func testEdgeChangeMouseBecameActive() {
        let prev: InputEventMapper.RhythmResult = .init(keyboardActive: false, mouseActive: false, isIdle: true)
        let curr: InputEventMapper.RhythmResult = .init(keyboardActive: false, mouseActive: true, isIdle: false)
        let edge = mapper.edgeChange(current: curr, previous: prev)
        expect(edge.mouseBecameActive, "mouse should become active when transitioning from inactive")
        expect(!edge.keyboardBecameActive, "keyboard should not become active when only mouse changed")
    }

    func testEdgeChangeBecameIdle() {
        let prev: InputEventMapper.RhythmResult = .init(keyboardActive: true, mouseActive: false, isIdle: false)
        let curr: InputEventMapper.RhythmResult = .init(keyboardActive: false, mouseActive: false, isIdle: true)
        let edge = mapper.edgeChange(current: curr, previous: prev)
        expect(edge.becameIdle, "should become idle when transitioning from active")
        expect(!edge.keyboardBecameActive, "keyboard should not become active when going idle")
    }

    func testIdleAfterThreshold() {
        _ = mapper.classify(keyboardCount: 1, mouseCount: 0, intensity: .moderate, now: now)
        let later = now.addingTimeInterval(11)
        let result = mapper.classify(keyboardCount: 0, mouseCount: 0, intensity: .moderate, now: later)
        expect(result.isIdle, "should detect idle after 11s of no events")
    }

    func testBothKeyboardAndMouseActive() {
        let result = mapper.classify(keyboardCount: 3, mouseCount: 20, intensity: .moderate, now: now)
        expect(result.keyboardActive, "both active: keyboard should be active")
        expect(result.mouseActive, "both active: mouse should be active")
        expect(!result.isIdle, "both active: should not be idle")
    }

    testExpressiveKeyboardTriggersWithOneEvent()
    testExpressiveKeyboardDoesNotTriggerWithZero()
    testModerateKeyboardRequiresTwoEvents()
    testSubtleKeyboardRequiresFourEvents()
    testExpressiveMouseTriggersWithFiveEvents()
    testModerateMouseRequiresFifteenEvents()
    testSubtleMouseRequiresFortyEvents()
    testEdgeChangeKeyboardBecameActive()
    testEdgeChangeMouseBecameActive()
    testEdgeChangeBecameIdle()
    testIdleAfterThreshold()
    testBothKeyboardAndMouseActive()
}
