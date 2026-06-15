import os

/// 桌面宠物统一日志系统
///
/// 基于 Apple OSLog 的分模块日志，按功能域划分 category，
/// 方便在 Console.app 中按子系统过滤查看。
public enum DesktopPetLog {
    /// 统一子系统标识符
    public static let subsystem = "DesktopPet"

    // MARK: - 日志分类标识

    /// 窗口管理
    public static let windowCategory = "window"
    /// 宠物引擎（状态机、行为调度）
    public static let engineCategory = "engine"
    /// 资源加载
    public static let assetsCategory = "assets"
    /// 用户偏好
    public static let preferencesCategory = "preferences"
    /// 开机自启
    public static let launchAtLoginCategory = "launchAtLogin"
    /// 宠物图库（导入、导出、管理）
    public static let petLibraryCategory = "petLibrary"
    /// Petdex 格式导入
    public static let petdexCategory = "petdex"
    /// 气泡对话
    public static let bubbleCategory = "bubble"
    /// AI 陪伴
    public static let aiCompanionCategory = "aiCompanion"

    /// 所有已注册的日志分类名集合
    public static let categoryNames: Set<String> = [
        windowCategory,
        engineCategory,
        assetsCategory,
        preferencesCategory,
        launchAtLoginCategory,
        petLibraryCategory,
        petdexCategory,
        bubbleCategory,
        aiCompanionCategory
    ]

    // MARK: - 各模块 Logger 实例

    /// 窗口日志
    public static let window = Logger(subsystem: subsystem, category: windowCategory)
    /// 引擎日志
    public static let engine = Logger(subsystem: subsystem, category: engineCategory)
    /// 资源日志
    public static let assets = Logger(subsystem: subsystem, category: assetsCategory)
    /// 偏好日志
    public static let preferences = Logger(subsystem: subsystem, category: preferencesCategory)
    /// 开机自启日志
    public static let launchAtLogin = Logger(subsystem: subsystem, category: launchAtLoginCategory)
    /// 图库日志
    public static let petLibrary = Logger(subsystem: subsystem, category: petLibraryCategory)
    /// Petdex 日志
    public static let petdex = Logger(subsystem: subsystem, category: petdexCategory)
    /// 气泡日志
    public static let bubble = Logger(subsystem: subsystem, category: bubbleCategory)
    /// AI 陪伴日志
    public static let aiCompanion = Logger(subsystem: subsystem, category: aiCompanionCategory)
}
