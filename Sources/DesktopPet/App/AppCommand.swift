import Foundation

/// 应用层统一命令枚举
///
/// 所有用户操作（菜单、设置面板、宠物交互）都映射为此枚举的一个 case，
/// 由 AppCoordinator 统一路由处理，实现单向数据流。
public enum AppCommand: Equatable {
    // MARK: - 宠物显示控制
    /// 显示宠物
    case showPet
    /// 隐藏宠物
    case hidePet

    // MARK: - 基础交互
    /// 点击宠物
    case clicked
    /// 抚摸宠物
    case pet
    /// 喂食宠物
    case feed
    /// 睡觉/唤醒切换
    case sleepOrWake

    // MARK: - 动作控制
    /// 播放指定动作
    case playAction(ActionId)
    /// 重置位置到默认
    case resetPosition

    // MARK: - 设置
    /// 打开设置面板
    case openSettings
    /// 设置开机自启
    case setLaunchAtLogin(Bool)
    /// 退出应用
    case quit

    // MARK: - 宠物图库
    /// 导入图片作为宠物
    case importPetImage(URL, displayName: String)
    /// 导入 .pet 包
    case importPetPackage(URL)
    /// 导入 Petdex 压缩包
    case importPetdexPackage(URL)
    /// 从 Petdex URL 导入
    case importPetdexURL(String)
    /// 取消 Petdex URL 导入
    case cancelPetdexURLImport
    /// 选择指定宠物
    case selectPet(String)
    /// 删除指定宠物
    case deletePet(String)

    // MARK: - 气泡
    /// 开关语音气泡
    case setSpeechBubbleEnabled(Bool)
    /// 设置气泡频率
    case setBubbleFrequency(BubbleFrequency)
    /// 开关亲密关系提示
    case setRelationshipPromptsEnabled(Bool)
    /// 静音一小时
    case quietForOneHour
    /// 清除静音模式
    case clearQuietMode

    // MARK: - 迷你对话
    /// 选择迷你对话选项
    case selectMicroDialogOption(MicroDialogOptionId)

    // MARK: - AI 聊天
    /// 打开聊天面板
    case openChatPanel(petId: String)
    /// 关闭聊天面板
    case closeChatPanel
    /// 发送聊天消息
    case sendChatMessage(text: String, petId: String)
    /// 开关 AI 功能
    case toggleAI(enabled: Bool)

    // MARK: - AI 记忆
    /// 清除 AI 记忆
    case clearAIMemory(petId: String)
    /// 导出 AI 记忆
    case exportAIMemory(petId: String)
    /// 删除单条记忆
    case deleteAIMemory(memoryId: String, petId: String)

    // MARK: - AI 偏好
    /// 更新 AI 偏好设置
    case updateAIPreferences(AICompanionPreferences)
    /// 选择 AI 性格
    case selectPersonality(profileId: String)

    // MARK: - 内容包管理
    /// 导入内容包
    case importContentPack(from: URL)
    /// 移除内容包
    case removeContentPack(packId: String)
    /// 启用内容包
    case enableContentPack(packId: String)
    /// 禁用内容包
    case disableContentPack(packId: String)
    /// 恢复默认内容
    case restoreDefaultContent
    /// 切换界面语言
    case setAppLanguage(AppLanguage)
}

/// 菜单栏当前状态的快照
///
/// 供菜单栏控制器读取，决定各菜单项的文案和状态。
public struct AppMenuState: Equatable {
    /// 宠物是否可见
    public var isPetVisible: Bool
    /// 宠物是否在睡觉
    public var isSleeping: Bool
    /// 开机自启是否开启
    public var isLaunchAtLoginEnabled: Bool
    /// 语音气泡是否开启
    public var isSpeechBubbleEnabled: Bool
    /// 是否处于静音模式
    public var isQuietModeActive: Bool
    /// 动作触发结果提示文案（如"宠物正忙"）
    public var actionNotice: String?

    public init(
        isPetVisible: Bool,
        isSleeping: Bool,
        isLaunchAtLoginEnabled: Bool,
        isSpeechBubbleEnabled: Bool = true,
        isQuietModeActive: Bool = false,
        actionNotice: String? = nil
    ) {
        self.isPetVisible = isPetVisible
        self.isSleeping = isSleeping
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.isSpeechBubbleEnabled = isSpeechBubbleEnabled
        self.isQuietModeActive = isQuietModeActive
        self.actionNotice = actionNotice
    }
}
