import Foundation

/// 语言管理器
///
/// 以 ObservableObject 形式管理当前界面语言，持久化到 UserDefaults。
/// 所有需要语言感知的视图可观察此对象自动刷新。
@MainActor
public final class LanguageManager: ObservableObject {
    /// 当前语言（变更时自动通知 SwiftUI）
    @Published public var currentLanguage: AppLanguage {
        didSet {
            guard oldValue != currentLanguage else { return }
            // 持久化到 UserDefaults
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: PreferenceKeys.appLanguage)
            DesktopPetLog.preferences.info("Language switched to \(self.currentLanguage.rawValue, privacy: .public)")
            onChange?()
        }
    }

    /// 语言变更回调（供非 SwiftUI 组件监听）
    public var onChange: (() -> Void)?

    public init() {
        let stored = UserDefaults.standard.string(forKey: PreferenceKeys.appLanguage)
        currentLanguage = AppLanguage.from(identifier: stored)
    }
}
