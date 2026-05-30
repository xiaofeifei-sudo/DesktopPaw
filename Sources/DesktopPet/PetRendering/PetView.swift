import Combine
import SwiftUI

@MainActor
public final class PetViewModel: ObservableObject {
    @Published public private(set) var runtimeState: PetRuntimeState
    @Published public private(set) var definition: PetDefinition?
    @Published public private(set) var bubble: PetBubble?
    @Published public private(set) var interactiveBubble: InteractiveBubble?
    @Published public private(set) var interactiveBubbleFeedbackText: String?
    @Published public private(set) var visualOverlay: PetVisualOverlayState?
    public var onInteractiveBubbleOptionTap: ((BubbleOption) -> Void)?

    public init(
        runtimeState: PetRuntimeState = .defaultState(),
        definition: PetDefinition? = nil,
        bubble: PetBubble? = nil
    ) {
        self.runtimeState = runtimeState
        self.definition = definition
        self.bubble = bubble
    }

    public func update(_ runtimeState: PetRuntimeState) {
        self.runtimeState = runtimeState
    }

    public func update(definition: PetDefinition?) {
        self.definition = definition
    }

    public func update(bubble: PetBubble?) {
        self.bubble = bubble
    }

    public func update(interactiveBubble: InteractiveBubble?) {
        self.interactiveBubble = interactiveBubble
    }

    public func update(interactiveBubbleFeedbackText: String?) {
        self.interactiveBubbleFeedbackText = interactiveBubbleFeedbackText
    }

    public func update(visualOverlay: PetVisualOverlayState?) {
        self.visualOverlay = visualOverlay
    }

    public func handleInteractiveBubbleOption(_ option: BubbleOption) {
        onInteractiveBubbleOptionTap?(option)
    }
}

@MainActor
public struct PetView: View {
    @ObservedObject private var model: PetViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let definition: PetDefinition
    private let renderer: PetRenderable
    private let motionProvider: PetMotionProviding
    private let reducedMotionOverride: Bool?
    private let onAnimationCompleted: ((PetState) -> Void)?
    private let frameTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    @State private var player: AnimationPlayer
    @State private var lastTickDate: Date?
    @State private var motionElapsedSeconds: TimeInterval = 0

    public init(
        model: PetViewModel,
        definition: PetDefinition,
        renderer: PetRenderable? = nil,
        motionProvider: PetMotionProviding = DefaultPetMotionProvider(),
        reducedMotion: Bool? = nil,
        onAnimationCompleted: ((PetState) -> Void)? = nil
    ) {
        self.model = model
        self.definition = definition
        self.renderer = renderer ?? DefaultPetRenderableFactory().makeRenderer(for: definition, folderURL: nil)
        self.motionProvider = motionProvider
        self.reducedMotionOverride = reducedMotion
        self.onAnimationCompleted = onAnimationCompleted

        let clip = Self.animationClip(for: definition, state: model.runtimeState)
        self._player = State(initialValue: AnimationPlayer(clip: clip, reducedMotion: false))
    }

    public var body: some View {
        let runtimeState = model.runtimeState
        let reducedMotion = reducedMotionOverride ?? accessibilityReduceMotion
        let renderSize = Self.renderSize(for: definition, state: runtimeState)
        let motionValue = motionProvider.motionValue(
            for: runtimeState.currentState,
            profile: definition.resolvedMotionProfile(),
            elapsed: motionElapsedSeconds,
            reducedMotion: reducedMotion
        )

        VStack(spacing: 8) {
            if model.interactiveBubble != nil || model.interactiveBubbleFeedbackText != nil {
                InteractiveBubbleContainerView(
                    bubble: model.interactiveBubble,
                    feedbackText: model.interactiveBubbleFeedbackText,
                    onOptionTap: { option in model.handleInteractiveBubbleOption(option) },
                    reducedMotion: reducedMotion
                )
                .id(model.interactiveBubble?.id.uuidString ?? model.interactiveBubbleFeedbackText ?? "")
                .transition(.opacity)
                .animation(
                    InteractiveBubbleContainerView.appearAnimation(reducedMotion: reducedMotion),
                    value: model.interactiveBubble?.id.uuidString ?? model.interactiveBubbleFeedbackText ?? ""
                )
            } else if let bubble = model.bubble {
                Text(bubble.text)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .transition(.opacity)
                    .animation(reducedMotion ? nil : .easeOut(duration: 0.18), value: bubble.id)
            }

            PetRenderHostView(
                renderer: renderer,
                state: runtimeState.currentState,
                frame: player.currentFrame,
                renderSize: renderSize,
                motionValue: motionValue,
                visualOverlay: model.visualOverlay,
                reducedMotion: reducedMotion
            )
        }
        .onReceive(frameTimer) { date in
            advanceAnimation(at: date)
        }
        .onChange(of: runtimeState.currentState) { _ in
            resetAnimation(for: model.runtimeState)
        }
        .onChange(of: runtimeState.currentActionId) { _ in
            resetAnimation(for: model.runtimeState)
        }
    }

    nonisolated public static func renderSize(for definition: PetDefinition, state: PetRuntimeState) -> CGSize {
        CGSize(
            width: definition.frameSize.width * state.scale,
            height: definition.frameSize.height * state.scale
        )
    }

    public static func animationClip(for definition: PetDefinition, state: PetRuntimeState) -> AnimationClip {
        if let actionId = state.currentActionId,
           let clip = definition.clip(for: actionId) {
            return clip
        }

        return definition.animation(for: state.currentState) ?? fallbackClip
    }

    private func advanceAnimation(at date: Date) {
        defer {
            lastTickDate = date
        }

        guard let lastTickDate else {
            player.reducedMotion = false
            return
        }

        player.reducedMotion = false
        let elapsedSeconds = max(0, date.timeIntervalSince(lastTickDate))
        motionElapsedSeconds += elapsedSeconds
        let elapsedMs = Int(elapsedSeconds * 1000)
        let result = player.advance(by: elapsedMs)

        if let nextState = result.completedNextState {
            onAnimationCompleted?(nextState)
        }
    }

    private func resetAnimation(for state: PetRuntimeState) {
        let clip = Self.animationClip(for: definition, state: state)
        player.reset(to: clip, reducedMotion: false)
        lastTickDate = nil
        motionElapsedSeconds = 0
    }

    private static let fallbackClip = AnimationClip(
        state: .idle,
        frames: [SpriteFrame(column: 0, row: 0)],
        frameDurationMs: 1_000,
        loop: true
    )
}
