import Foundation
import SwiftUI

public struct FeatureInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let whyNeeded: String
    public let whatItAccesses: String
    public let whatItDoesNotAccess: String
    public let dataSaved: String
    public let howToClose: String
    public let whatYouLose: String

    public init(
        id: String,
        title: String,
        whyNeeded: String,
        whatItAccesses: String,
        whatItDoesNotAccess: String,
        dataSaved: String,
        howToClose: String,
        whatYouLose: String
    ) {
        self.id = id
        self.title = title
        self.whyNeeded = whyNeeded
        self.whatItAccesses = whatItAccesses
        self.whatItDoesNotAccess = whatItDoesNotAccess
        self.dataSaved = dataSaved
        self.howToClose = howToClose
        self.whatYouLose = whatYouLose
    }
}

@MainActor
public final class AdvancedSettingsViewModel: ObservableObject {
    @Published public var preferences: AdvancedPreferences
    @Published public var showInputSyncInfo = false
    @Published public var showDesktopSpaceInfo = false
    @Published public var showExternalStateInfo = false
    @Published public var showContentPackManager = false

    public var onInputSyncEnabledChanged: ((Bool) -> Void)?
    public var onInputSyncIntensityChanged: ((InputSyncIntensity) -> Void)?
    public var onInputSyncTrackKeyboardChanged: ((Bool) -> Void)?
    public var onInputSyncTrackMouseChanged: ((Bool) -> Void)?
    public var onInputSyncRespectQuietModeChanged: ((Bool) -> Void)?
    public var onDesktopSpaceEnabledChanged: ((Bool) -> Void)?
    public var onDesktopSpaceEdgeThresholdChanged: ((Double) -> Void)?
    public var onMovementConstrainedChanged: ((Bool) -> Void)?
    public var onExternalStateEnabledChanged: ((Bool) -> Void)?

    public let contentPackViewModel: ContentPackViewModel?

    public init(
        preferences: AdvancedPreferences = .default,
        contentPackViewModel: ContentPackViewModel? = nil
    ) {
        self.preferences = preferences
        self.contentPackViewModel = contentPackViewModel
    }

    public func updatePreferences(_ preferences: AdvancedPreferences) {
        self.preferences = preferences
    }

    public nonisolated static let inputSyncInfo = FeatureInfo(
        id: "inputSync",
        title: "Input Sync",
        whyNeeded: "让桌宠根据你的键盘和鼠标输入节奏做出同步动作，提升陪伴感和互动性。",
        whatItAccesses: "键盘敲击事件类型（仅计数，不记录具体按键）和鼠标移动事件类型（仅计数，不记录位置）。",
        whatItDoesNotAccess: "不记录按下的具体按键、不记录鼠标精确位置、不读取输入内容文字。",
        dataSaved: "输入节奏计数每 1.5 秒重置，不保存任何输入数据。开关和强度配置保存在本地偏好中。",
        howToClose: "在此页面关闭开关即可。也可以在系统设置中撤销辅助功能权限。",
        whatYouLose: "关闭后宠物不再响应键盘和鼠标节奏，但仍可通过点击、抚摸等本地互动进行陪伴。"
    )

    public nonisolated static let desktopSpaceInfo = FeatureInfo(
        id: "desktopSpace",
        title: "Desktop Space",
        whyNeeded: "让桌宠感知屏幕边界和窗口位置，做出更自然的空间行为（如坐在窗口边缘、看向屏幕外侧）。",
        whatItAccesses: "屏幕大小和可见区域、桌面窗口的位置和大小（仅获取窗口矩形，不获取窗口标题和应用名称）。",
        whatItDoesNotAccess: "不读取窗口标题、不读取窗口内容、不获取应用名称、不读取进程信息。",
        dataSaved: "边缘检测阈值和运动限制设置保存在本地偏好中。不保存屏幕或窗口数据。",
        howToClose: "在此页面关闭开关即可。",
        whatYouLose: "关闭后宠物恢复默认的随机走动行为，不再响应屏幕边界和窗口位置。"
    )

    public nonisolated static let externalStateInfo = FeatureInfo(
        id: "externalState",
        title: "External State",
        whyNeeded: "让外部工具（如构建脚本、自动化工具）通过本地连接通知桌宠显示动作或气泡，适合开发者和高级用户。",
        whatItAccesses: "通过本地 Unix Socket 接收 JSON 事件文本（仅文本解析，不执行代码）。",
        whatItDoesNotAccess: "不连接网络、不执行脚本、不访问文件系统、不读取其他应用数据。",
        dataSaved: "事件到动作/气泡的映射配置保存在本地偏好中。不保存事件数据。",
        howToClose: "在此页面关闭开关即可，同时会断开所有外部连接。",
        whatYouLose: "关闭后外部工具无法再与桌宠通信，之前配置的事件映射保留但不会触发。"
    )
}
