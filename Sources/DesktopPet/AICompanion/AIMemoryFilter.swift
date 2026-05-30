import Foundation

public protocol AIMemoryFiltering: Sendable {
    func filter(_ content: String) -> MemoryFilterResult
}

public struct MemoryFilterResult: Sendable, Equatable {
    public let isAllowed: Bool
    public let reason: String?
    public let isSensitive: Bool

    public init(isAllowed: Bool, reason: String? = nil, isSensitive: Bool = false) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.isSensitive = isSensitive
    }

    public static let allowed = MemoryFilterResult(isAllowed: true)
}

public struct AIMemoryFilter: AIMemoryFiltering, Sendable {
    public init() {}

    public func filter(_ content: String) -> MemoryFilterResult {
        if containsIDNumber(content) {
            return MemoryFilterResult(isAllowed: false, reason: "包含疑似证件号码")
        }
        if containsPassword(content) {
            return MemoryFilterResult(isAllowed: false, reason: "包含疑似密码信息")
        }
        if containsExactAddress(content) {
            return MemoryFilterResult(isAllowed: false, reason: "包含疑似精确地址")
        }
        if containsMedicalInfo(content) {
            return MemoryFilterResult(isAllowed: false, reason: "包含疑似医疗信息")
        }
        if containsSensitiveContent(content) {
            return MemoryFilterResult(isAllowed: true, isSensitive: true)
        }
        return .allowed
    }

    private func containsIDNumber(_ text: String) -> Bool {
        let patterns = [
            "(?:\\d{17}[\\dXx])",
            "(?:\\d{15})",
        ]
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private func containsPassword(_ text: String) -> Bool {
        let keywords = ["密码", "password", "passwd", "pwd", "passcode", "pin码", "验证码"]
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0) }
    }

    private func containsExactAddress(_ text: String) -> Bool {
        let patterns = [
            "\\d+号\\d+室",
            "\\d+栋\\d+号",
            "省.+市.+区.+路\\d+号",
            "路\\d+号\\d+楼",
        ]
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private func containsMedicalInfo(_ text: String) -> Bool {
        let keywords = [
            "确诊", "诊断", "处方", "病历", "检查报告",
            "血压", "血糖", "心率", "肿瘤", "癌症",
            "手术", "化疗", "放疗", "住院", "急诊",
            "diagnosis", "prescription", "medical report",
        ]
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0) }
    }

    private func containsSensitiveContent(_ text: String) -> Bool {
        let keywords = [
            "抑郁", "焦虑", "失眠", "崩溃", "想哭", "难过", "伤心",
            "压力", "崩溃", "烦躁", "无助", "孤独", "不想活", "自残",
            "分手", "离婚", "失业", "吵架", "失败",
        ]
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0) }
    }
}
