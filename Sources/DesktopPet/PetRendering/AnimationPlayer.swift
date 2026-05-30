import Foundation

public struct AnimationPlayerAdvance: Equatable {
    public let frame: SpriteFrame?
    public let completedNextState: PetState?

    public init(frame: SpriteFrame?, completedNextState: PetState?) {
        self.frame = frame
        self.completedNextState = completedNextState
    }
}

public struct AnimationPlayer: Equatable {
    public private(set) var clip: AnimationClip
    public private(set) var currentFrameIndex: Int
    public private(set) var elapsedInCurrentFrameMs: Int
    public private(set) var isComplete: Bool
    public var reducedMotion: Bool

    public init(clip: AnimationClip, reducedMotion: Bool = false) {
        self.clip = clip
        self.currentFrameIndex = 0
        self.elapsedInCurrentFrameMs = 0
        self.isComplete = false
        self.reducedMotion = reducedMotion
    }

    public var currentFrame: SpriteFrame? {
        guard !clip.frames.isEmpty else {
            return nil
        }

        return clip.frames[min(currentFrameIndex, clip.frames.count - 1)]
    }

    public mutating func reset(to clip: AnimationClip, reducedMotion: Bool? = nil) {
        self.clip = clip
        self.currentFrameIndex = 0
        self.elapsedInCurrentFrameMs = 0
        self.isComplete = false

        if let reducedMotion {
            self.reducedMotion = reducedMotion
        }
    }

    @discardableResult
    public mutating func advance(by elapsedMs: Int) -> AnimationPlayerAdvance {
        guard !clip.frames.isEmpty else {
            return AnimationPlayerAdvance(frame: nil, completedNextState: nil)
        }

        guard elapsedMs > 0, !isComplete else {
            return AnimationPlayerAdvance(frame: currentFrame, completedNextState: nil)
        }

        if reducedMotion {
            return advanceReducedMotion(by: elapsedMs)
        }

        if clip.loop {
            advanceLoopingClip(by: elapsedMs)
            return AnimationPlayerAdvance(frame: currentFrame, completedNextState: nil)
        }

        let completedNextState = advanceNonLoopingClip(by: elapsedMs)
        return AnimationPlayerAdvance(frame: currentFrame, completedNextState: completedNextState)
    }

    public func durationMs(for frame: SpriteFrame) -> Int {
        max(1, frame.durationMs ?? clip.frameDurationMs)
    }

    private mutating func advanceReducedMotion(by elapsedMs: Int) -> AnimationPlayerAdvance {
        guard !clip.loop else {
            elapsedInCurrentFrameMs = 0
            return AnimationPlayerAdvance(frame: currentFrame, completedNextState: nil)
        }

        let remainingMs = max(totalDurationMs - timelineOffsetMs, 0)
        guard elapsedMs < remainingMs else {
            isComplete = true
            elapsedInCurrentFrameMs = 0
            return AnimationPlayerAdvance(frame: currentFrame, completedNextState: clip.nextState)
        }

        elapsedInCurrentFrameMs += elapsedMs
        return AnimationPlayerAdvance(frame: currentFrame, completedNextState: nil)
    }

    private mutating func advanceLoopingClip(by elapsedMs: Int) {
        let total = totalDurationMs
        guard total > 0 else { return }

        let offset = (timelineOffsetMs % total + elapsedMs % total) % total
        seek(toTimelineOffsetMs: offset)
    }

    private mutating func advanceNonLoopingClip(by elapsedMs: Int) -> PetState? {
        let total = totalDurationMs
        let currentOffset = timelineOffsetMs
        let remainingMs = max(total - currentOffset, 0)

        guard elapsedMs < remainingMs else {
            currentFrameIndex = max(clip.frames.count - 1, 0)
            isComplete = true
            elapsedInCurrentFrameMs = 0
            return clip.nextState
        }

        seek(toTimelineOffsetMs: currentOffset + elapsedMs)
        return nil
    }

    private var totalDurationMs: Int {
        clip.frames.reduce(0) { total, frame in
            total + durationMs(for: frame)
        }
    }

    private var timelineOffsetMs: Int {
        var offset = elapsedInCurrentFrameMs
        guard currentFrameIndex > 0 else {
            return offset
        }

        for index in 0..<currentFrameIndex {
            offset += durationMs(for: clip.frames[index])
        }
        return offset
    }

    private mutating func seek(toTimelineOffsetMs offset: Int) {
        var remainingMs = max(offset, 0)

        for (index, frame) in clip.frames.enumerated() {
            let duration = durationMs(for: frame)
            if remainingMs < duration {
                currentFrameIndex = index
                elapsedInCurrentFrameMs = remainingMs
                return
            }
            remainingMs -= duration
        }

        currentFrameIndex = max(clip.frames.count - 1, 0)
        elapsedInCurrentFrameMs = 0
    }
}
