import Foundation

/// 气泡指挥官
///
/// 在 BubbleEngine 之上封装一层，统一管理所有气泡事件路由：
/// - 基础交互（点击/抚摸/喂食）
/// - 引擎 tick
/// - AI 陪伴触发
///
/// 核心职责是监听引擎输出，当气泡发生变化时通过 onBubbleChanged 广播出去。
@MainActor
public final class BubbleCommander: BubbleCommanding {
    /// 底层气泡引擎
    private let bubbleEngine: BubbleEngine
    /// 上一次的气泡，用于变更检测
    private var lastBubble: PetBubble?

    /// 当气泡发生变化时回调（nil 表示消失）
    public var onBubbleChanged: ((PetBubble?) -> Void)?

    public init(bubbleEngine: BubbleEngine) {
        self.bubbleEngine = bubbleEngine
        self.lastBubble = bubbleEngine.currentBubble
    }

    public var currentBubble: PetBubble? { bubbleEngine.currentBubble }

    // MARK: - 配置

    /// 开关语音气泡
    public func setSpeechBubbleEnabled(_ enabled: Bool) {
        bubbleEngine.isEnabled = enabled
        publishCurrent()
    }

    /// 调整气泡弹出频率
    public func setBubbleFrequency(_ frequency: BubbleFrequency) {
        bubbleEngine.frequency = frequency
    }

    // MARK: - 事件处理

    /// 处理基础宠物交互事件
    public func handleInteraction(_ event: PetEvent, state: PetRuntimeState, at date: Date) {
        _ = bubbleEngine.handle(event: event, state: state, at: date)
        publishCurrent()
    }

    /// 处理引擎 tick（定时触发）
    public func handleTick(state: PetRuntimeState, at date: Date) {
        _ = bubbleEngine.tick(state: state, at: date)
        publishCurrent()
    }

    /// 处理 AI 陪伴触发事件
    public func handleCompanionInteraction(_ trigger: BubbleTrigger, context: CompanionContext, at date: Date) {
        _ = bubbleEngine.handle(trigger: trigger, context: context, at: date)
        publishCurrent()
    }

    /// 处理 AI 陪伴 tick
    public func handleCompanionTick(context: CompanionContext, at date: Date) {
        _ = bubbleEngine.tick(context: context, at: date)
        publishCurrent()
    }

    // MARK: - 广播

    /// 检测气泡变更并广播
    private func publishCurrent() {
        let current = bubbleEngine.currentBubble
        guard current != lastBubble else {
            return
        }

        lastBubble = current
        onBubbleChanged?(current)
    }
}
