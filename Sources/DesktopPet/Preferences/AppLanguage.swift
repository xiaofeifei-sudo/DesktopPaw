import Foundation

/// 应用支持的语言枚举
public enum AppLanguage: String, CaseIterable, Sendable {
    /// 简体中文
    case chinese = "zh-Hans"
    /// 英文
    case english = "en"

    /// 显示名称
    public var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    /// 短标识
    public var shortName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "EN"
        }
    }

    /// 从 rawValue 创建，无效时返回默认值
    public static func from(identifier: String?) -> AppLanguage {
        guard let identifier else { return .default }
        return AppLanguage(rawValue: identifier) ?? .default
    }

    /// 系统默认语言（中文优先）
    public static let `default`: AppLanguage = .chinese
}
