import Foundation

public final class InputEventMapper: @unchecked Sendable {
    public struct RhythmResult: Equatable, Sendable {
        public var keyboardActive: Bool
        public var mouseActive: Bool
        public var isIdle: Bool

        public init(keyboardActive: Bool, mouseActive: Bool, isIdle: Bool) {
            self.keyboardActive = keyboardActive
            self.mouseActive = mouseActive
            self.isIdle = isIdle
        }

        public static let idle = RhythmResult(keyboardActive: false, mouseActive: false, isIdle: true)
    }

    private let analysisWindow: TimeInterval = 1.5
    private let idleThreshold: TimeInterval = 10.0
    private var lastKeyboardActivityAt: Date = Date()
    private var lastMouseActivityAt: Date = Date()
    private var previousKeyboardActive = false
    private var previousMouseActive = false

    public init() {}

    public func classify(
        keyboardCount: Int,
        mouseCount: Int,
        intensity: InputSyncIntensity,
        now: Date
    ) -> RhythmResult {
        let keyboardActive: Bool
        let mouseActive: Bool

        if keyboardCount > 0 {
            lastKeyboardActivityAt = now
        }
        if mouseCount > 0 {
            lastMouseActivityAt = now
        }

        switch intensity {
        case .expressive:
            keyboardActive = keyboardCount >= 1
            mouseActive = mouseCount >= 5
        case .moderate:
            keyboardActive = keyboardCount >= 2
            mouseActive = mouseCount >= 15
        case .subtle:
            keyboardActive = keyboardCount >= 4
            mouseActive = mouseCount >= 40
        }

        let keyboardIdle = now.timeIntervalSince(lastKeyboardActivityAt) >= idleThreshold
        let mouseIdle = now.timeIntervalSince(lastMouseActivityAt) >= idleThreshold
        let isIdle = keyboardIdle && mouseIdle

        previousKeyboardActive = keyboardActive
        previousMouseActive = mouseActive

        return RhythmResult(
            keyboardActive: keyboardActive,
            mouseActive: mouseActive,
            isIdle: isIdle
        )
    }

    public func edgeChange(
        current: RhythmResult,
        previous: RhythmResult
    ) -> (keyboardBecameActive: Bool, mouseBecameActive: Bool, becameIdle: Bool) {
        (
            keyboardBecameActive: current.keyboardActive && !previous.keyboardActive,
            mouseBecameActive: current.mouseActive && !previous.mouseActive,
            becameIdle: current.isIdle && !previous.isIdle
        )
    }
}
