import Foundation

/// 界面字符串集中管理
///
/// 根据 AppLanguage 返回对应语言的字符串，避免代码中硬编码文案。
/// 当前覆盖核心 UI（菜单栏、设置页及其子视图），后续可逐步扩展覆盖全部界面。
public enum L10n {
    // MARK: - 当前语言

    /// 当前语言（需在 LanguageManager 注入后调用，仅主线程写入）
    nonisolated(unsafe) public static var language: AppLanguage = .default

    // MARK: - 菜单栏

    public enum Menu {
        public static var hidePet: String { lang("隐藏宠物", "Hide Pet") }
        public static var showPet: String { lang("显示宠物", "Show Pet") }
        public static var pet: String { lang("抚摸", "Pet") }
        public static var feed: String { lang("喂食", "Feed") }
        public static var wake: String { lang("叫醒", "Wake") }
        public static var sleep: String { lang("睡觉", "Sleep") }
        public static var actions: String { lang("动作", "Actions") }
        public static var more: String { lang("更多", "More") }
        public static var resumeBubbles: String { lang("恢复气泡", "Resume Bubbles") }
        public static var quietForOneHour: String { lang("静音一小时", "Quiet for 1 Hour") }
        public static var hideBubbles: String { lang("隐藏气泡", "Hide Bubbles") }
        public static var showBubbles: String { lang("显示气泡", "Show Bubbles") }
        public static var resetPosition: String { lang("重置位置", "Reset Position") }
        public static var startChat: String { lang("开始聊天", "Start Chat") }
        public static var settings: String { lang("设置", "Settings") }
        public static var launchAtLogin: String { lang("开机自启", "Launch at Login") }
        public static var quit: String { lang("退出", "Quit") }
        public static var language: String { lang("语言", "Language") }
    }

    // MARK: - 设置页 Section 标题

    public enum Settings {
        public static var title: String { lang("桌面宠物设置", "Desktop Pet Settings") }
        public static var desktopPet: String { lang("桌面宠物", "Desktop Pet") }
        public static var showPet: String { lang("显示宠物", "Show Pet") }
        public static var randomWalking: String { lang("随机走动", "Random Walking") }
        public static var sound: String { lang("音效", "Sound") }
        public static var launchAtLogin: String { lang("开机自启", "Launch at Login") }
        public static var status: String { lang("状态", "Status") }
        public static var resetPosition: String { lang("重置位置", "Reset Position") }
        public static var customPet: String { lang("自定义宠物", "Custom Pet") }
        public static var speechBubbles: String { lang("语音气泡", "Speech Bubbles") }
        public static var smartBubbles: String { lang("智能气泡", "Smart Bubbles") }
        public static var companionship: String { lang("陪伴系统", "Companionship") }
        public static var aiCompanion: String { lang("AI 陪伴", "AI Companion") }
        public static var aiVisualExpression: String { lang("AI 视觉表现", "AI Visual Expression") }
        public static var language: String { lang("界面语言", "Language") }
        public static var yourNickname: String { lang("你的昵称", "Your nickname") }
    }

    // MARK: - 气泡设置

    public enum Bubble {
        public static var showSpeechBubbles: String { lang("显示语音气泡", "Show speech bubbles") }
        public static var frequency: String { lang("气泡频率", "Bubble Frequency") }
        public static var frequencyQuiet: String { lang("安静", "Quiet") }
        public static var frequencyNormal: String { lang("正常", "Normal") }
        public static var frequencyExpressive: String { lang("活跃", "Expressive") }
    }

    // MARK: - 陪伴设置

    public enum Companionship {
        public static var showRelationshipPrompts: String { lang("显示关系提示", "Show relationship prompts") }
        public static var petNickname: String { lang("宠物昵称", "Pet nickname") }
        public static var resetRelationship: String { lang("重置关系", "Reset relationship") }
        public static var resetConfirmTitle: String { lang("重置关系？", "Reset relationship?") }
        public static var reset: String { lang("重置", "Reset") }
        public static var resetMessage: String { lang("这将把当前宠物的关系重置回 Lv.1，不可撤销。", "This will reset your relationship with the current pet back to Lv.1. This cannot be undone.") }
        public static var relationship: String { lang("亲密关系", "Relationship") }
        public static var quietHours: String { lang("静音时段", "Quiet hours") }
        public static var from: String { lang("从", "From") }
        public static var to: String { lang("至", "To") }
        public static var quietActive: String { lang("静音模式已开启", "Quiet mode is currently active") }
        public static var resumeBubblesNow: String { lang("立即恢复气泡", "Resume bubbles now") }
        public static var quietForOneHour: String { lang("静音一小时", "Quiet for 1 hour") }
        public static var quietStatus: String { lang("静音", "Quiet") }
    }

    // MARK: - 智能气泡设置

    public enum SmartBubble {
        public static var enableSmartBubbles: String { lang("启用智能气泡", "Enable smart bubbles") }
        public static var advancedSettings: String { lang("高级设置", "Advanced Settings") }
        public static var hideAdvancedSettings: String { lang("隐藏高级设置", "Hide Advanced Settings") }
        public static var aiGuidance: String { lang("智能气泡需要 AI 支持。请先在 AI 设置中配置模型和 API Key。", "Smart bubbles need AI support. Configure a model and API key in AI Settings first.") }
        public static var openAISettings: String { lang("打开 AI 设置", "Open AI Settings") }
        public static var activity: String { lang("活跃度", "Activity") }
        public static var activityLow: String { lang("低", "Low") }
        public static var activityMedium: String { lang("中", "Medium") }
        public static var activityHigh: String { lang("高", "High") }
        public static var minInterval: String { lang("最小间隔", "Minimum Interval") }
        public static var maxInterval: String { lang("最大间隔", "Maximum Interval") }
        public static var optionWait: String { lang("选项等待", "Option Wait") }
        public static var silentPeriod: String { lang("静音时段", "Silent Period") }
        public static var to: String { lang("至", "to") }
    }

    // MARK: - AI 设置

    public enum AI {
        public static var title: String { lang("AI 陪伴", "AI Companion") }
        public static var aiOffWarning: String { lang("AI 功能默认关闭。开启后可以与宠物聊天。", "AI features are off by default. Enable to chat with your pet.") }
        public static var disableAI: String { lang("关闭 AI", "Disable AI") }
        public static var enableAI: String { lang("开启 AI", "Enable AI") }
        public static var aiProvider: String { lang("AI 服务商", "AI Provider") }
        public static var configured: String { lang("已配置", "Configured") }
        public static var notConfigured: String { lang("未配置 — 设置 API Key 即可开始聊天", "Not configured — set up API key to start chatting") }
        public static var configure: String { lang("配置", "Configure") }
        public static var personality: String { lang("性格", "Personality") }
        public static var allowInitiativeBubbles: String { lang("允许 AI 主动发起气泡", "Allow AI initiative bubbles") }
        public static var memory: String { lang("记忆", "Memory") }
        public static var viewManageMemory: String { lang("查看与管理记忆", "View & Manage Memory") }
        public static var exportMemory: String { lang("导出记忆", "Export Memory") }
        public static var clearAllMemory: String { lang("清除全部记忆", "Clear All Memory") }
        public static var beforeEnablingAI: String { lang("启用 AI 前须知", "Before Enabling AI") }
        public static var privacyProcessing: String { lang("AI 将处理你发送给宠物的文字消息。", "AI will process the text messages you send to your pet.") }
        public static var privacyMemory: String { lang("AI 可能使用记忆来记住你的偏好和昵称（需开启记忆）。", "AI may use memory to remember your preferences and nicknames (if enabled).") }
        public static var privacyDisable: String { lang("你可以随时在此设置页关闭 AI 功能。", "You can disable AI at any time from this settings page.") }
        public static var privacyManage: String { lang("你可以随时查看、编辑和清除所有 AI 记忆。", "You can view, edit, and clear all AI memory at any time.") }
        public static var privacyDisclaimer: String { lang("AI 不能替代专业的医疗、法律或财务建议。", "AI cannot replace professional medical, legal, or financial advice.") }
        public static var iUnderstand: String { lang("我已了解，开启 AI", "I Understand, Enable AI") }
        public static var configureAIProvider: String { lang("配置 AI 服务商", "Configure AI Provider") }
        public static var protocol_: String { lang("协议", "Protocol") }
        public static var openAI: String { "OpenAI" }
        public static var anthropic: String { "Anthropic" }
        public static var apiEndpoint: String { lang("API 地址", "API Endpoint") }
        public static var model: String { lang("模型", "Model") }
        public static var apiKey: String { lang("API Key", "API Key") }
        public static var noMemories: String { lang("暂无记忆", "No memories yet") }
        public static var exportComplete: String { lang("导出完成", "Export Complete") }
        public static var exportFailed: String { lang("导出失败", "Export Failed") }
        public static var clearAllMemoriesConfirm: String { lang("清除所有 AI 记忆？", "Clear all AI memories?") }
        public static var deleteAllCategory: String { lang("删除此分类下的所有记忆？", "Delete all memories in this category?") }
        public static var searchMemories: String { lang("搜索记忆...", "Search memories...") }
        public static var category: String { lang("分类", "Category") }
        public static var aiCategory: String { lang("AI", "AI") }
    }

    // MARK: - AI 视觉设置

    public enum AIVisual {
        public static var title: String { lang("AI 视觉表现", "AI Visual Expression") }
        public static var subtitle: String { lang("让 AI 为你的宠物创建临时视觉变化。", "Let AI create temporary visual changes for your pet.") }
        public static var enable: String { lang("启用", "Enable") }
        public static var disable: String { lang("禁用", "Disable") }
        public static var imageProvider: String { lang("图像服务商", "Image Provider") }
        public static var notConfigured: String { lang("未配置", "Not configured") }
        public static var reconfigure: String { lang("重新配置", "Reconfigure") }
        public static var configure: String { lang("配置", "Configure") }
        public static var providerRequiresAPIKey: String { lang("此服务商需要 API Key 来生成图像。", "This provider requires an API key to generate images.") }
        public static var setupGuide: String { lang("安装指南", "Setup Guide") }
        public static var installGuide: String { lang("安装：`brew install minimax/tap/mmx` 或从 minimax.ai 下载", "Install: `brew install minimax/tap/mmx` or download from minimax.ai") }
        public static var loginGuide: String { lang("登录：在命令行运行 `mmx auth login`", "Log in: run `mmx auth login` in your command line") }
        public static var refreshGuide: String { lang("安装或登录后点击「检查状态」", "Click \"Check Status\" after installing or logging in") }
        public static var mmxPathPlaceholder: String { lang("mmx 路径（可选）", "mmx path (optional)") }
        public static var checkStatus: String { lang("检查状态", "Check Status") }
        public static var dailyUsage: String { lang("今日用量", "Daily Usage") }
        public static var today: String { lang("今日", "Today") }
        public static var remaining: String { lang("剩余", "Remaining") }
        public static var thisMonth: String { lang("本月", "This Month") }
        public static var autonomousFrequency: String { lang("自动频率", "Autonomous Frequency") }
        public static var changeDuration: String { lang("变化持续时间", "Change Duration") }
        public static var changeIntensity: String { lang("变化强度", "Change Intensity") }
        public static var consistencyPreference: String { lang("一致性偏好", "Consistency Preference") }
        public static var visualNotes: String { lang("形象备注", "Visual Notes") }
        public static var visualNotesPlaceholder: String { lang("粉白色小狐狸，2D 插画风，不要 3D", "Pink-white fox, 2D illustration style, not 3D") }
        public static var visualNotesHint: String { lang("可选；会用于下一次生成。", "Optional; used for next generation.") }
        public static var manualGeneration: String { lang("手动生成", "Manual Generation") }
        public static var manualGenerationHint: String { lang("立即创建一次新的视觉变化。", "Create a fresh visual change now.") }
        public static var generateNow: String { lang("立即生成", "Generate Now") }
        public static var restoreOriginalLook: String { lang("恢复原始外观", "Restore Original Look") }
        public static var noActiveChange: String { lang("当前无视觉变化", "No active visual change") }
        public static var historyFavorites: String { lang("历史与收藏", "History & Favorites") }
        public static var viewHistoryHint: String { lang("查看和管理视觉变化历史", "View and manage visual change history") }
        public static var viewHistory: String { lang("查看历史", "View History") }
        public static var beforeEnabling: String { lang("启用 AI 视觉表现前须知", "Before Enabling AI Visual Expression") }
        public static var noticeVisual: String { lang("AI 可能会根据对话内容创建临时视觉变化。", "AI may create temporary visual changes based on your conversation.") }
        public static var noticeDelay: String { lang("生成可能需要几秒钟。你可以在等待时继续聊天。", "Changes may take a few seconds to generate. You can continue chatting while waiting.") }
        public static var noticeFail: String { lang("生成可能失败。如果失败，宠物将保持原样，并显示简短提示。", "Changes may fail. If so, your pet stays the same and a brief message is shown.") }
        public static var noticeQuota: String { lang("生成次数计入每日配额。你可以在设置中查看剩余次数。", "Changes count toward a daily quota. You can see remaining uses in settings.") }
        public static var noticeRevert: String { lang("所有变化均为临时效果，会自动恢复。你也可以立即手动恢复。", "All changes are temporary and auto-revert. You can also restore immediately.") }
        public static var noticePrivacy: String { lang("此功能不会读取你的屏幕、摄像头、麦克风或其他应用。", "This feature does not read your screen, camera, microphone, or other apps.") }
        public static var noticeDisable: String { lang("你可以随时在此设置页关闭此功能。", "You can disable this feature at any time from this settings page.") }
        public static var iUnderstandEnable: String { lang("我已了解，开启", "I Understand, Enable") }
        public static var configureProvider: String { lang("配置", "Configure") }
        public static var baseURL: String { lang("基础 URL", "Base URL") }
        public static var model: String { lang("模型", "Model") }
        public static var secretId: String { lang("Secret ID", "Secret ID") }
        public static var secretKey: String { lang("Secret Key", "Secret Key") }
        public static var apiKey: String { lang("API Key", "API Key") }
        public static var region: String { lang("区域", "Region") }
        public static var frequencyOffHint: String { lang("AI 不会主动创建视觉变化。", "AI will not create visual changes on its own.") }
        public static var frequencyLowHint: String { lang("AI 偶尔建议视觉变化（至少间隔 30 分钟）。", "AI may suggest visual changes occasionally (at least 30 min apart).") }
        public static var frequencyMediumHint: String { lang("AI 更频繁建议视觉变化（至少间隔 10 分钟）。", "AI may suggest visual changes more often (at least 10 min apart).") }
        public static var provider: String { lang("服务商", "Provider") }
        public static var notConfiguredShort: String { lang("（未配置）", "(not configured)") }
    }

    // MARK: - 宠物图库

    public enum PetLibrary {
        public static var title: String { lang("宠物图库", "Pet Library") }
        public static var noPets: String { lang("还没有导入宠物。请导入图片或宠物包来添加。", "No pets yet. Import an image or package to add one.") }
        public static var importImage: String { lang("导入图片", "Import Image") }
        public static var importPackage: String { lang("导入包", "Import Package") }
        public static var importPetdexZip: String { lang("导入 Petdex Zip", "Import Petdex Zip") }
        public static var importPetdexURL: String { lang("从 Petdex URL 导入", "Import from Petdex URL") }
        public static var importing: String { lang("导入中...", "Importing...") }
        public static var downloading: String { lang("下载中...", "Downloading...") }
        public static var imported: String { lang("已导入", "Imported.") }
        public static var cancelled: String { lang("已取消", "Cancelled.") }
        public static var importFailed: String { lang("导入失败", "Import failed.") }
        public static var petdexImportFailed: String { lang("Petdex 导入失败", "Petdex import failed.") }
        public static var importLater: String { lang("稍后导入", "Import Later") }
        public static var plannedNotice: String { lang("自定义宠物包功能计划在未来版本中推出。", "Custom pet packages are planned for a future version.") }
    }

    // MARK: - 内容包

    public enum ContentPack {
        public static var importPack: String { lang("导入", "Import") }
        public static var restoreDefaults: String { lang("恢复默认", "Restore Defaults") }
        public static var noPacks: String { lang("未安装内容包。", "No content packs installed.") }
        public static var disable: String { lang("禁用", "Disable") }
        public static var enable: String { lang("启用", "Enable") }
        public static var remove: String { lang("移除", "Remove") }
        public static var managePacks: String { lang("导入和管理对话、性格及动作包。", "Import and manage dialogue, personality, and action packs.") }
    }

    // MARK: - 通用按钮

    public enum Common {
        public static var cancel: String { lang("取消", "Cancel") }
        public static var save: String { lang("保存", "Save") }
        public static var delete: String { lang("删除", "Delete") }
        public static var ok: String { lang("确定", "OK") }
        public static var none: String { lang("无", "None") }
        public static var tags: String { lang("标签", "Tags") }
        public static var noActions: String { lang("无可用动作", "No actions available.") }
        public static var tokenPlan: String { lang("Token 计划", "Token Plan") }
        public static var phaseNotice: String { lang("第 3 阶段起参与加权抽样", "Phase 3 起将参与加权抽样") }
    }

    // MARK: - 语言名称

    public enum General {
        public static var chinese: String { lang("简体中文", "Simplified Chinese") }
        public static var english: String { lang("英语", "English") }
    }

    // MARK: - 辅助方法

    /// 根据当前语言选择对应的字符串（对外暴露，供需要内联翻译的场景使用）
    public static func localize(cn: String, en: String) -> String {
        switch language {
        case .chinese: return cn
        case .english: return en
        }
    }

    /// 根据当前语言选择对应的字符串
    private static func lang(_ cn: String, _ en: String) -> String {
        localize(cn: cn, en: en)
    }
}
