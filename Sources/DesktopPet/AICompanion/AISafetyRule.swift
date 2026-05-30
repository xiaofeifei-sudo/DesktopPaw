import Foundation

public enum AISafetyCategory: String, Sendable, Equatable, CaseIterable {
    case selfHarm
    case medicalPsychological
    case legalFinancial
    case minorRisk
    case violenceIllegal
    case dependencyInduction
    case possessiveExclusive
    case privacyLeak
    case roleOverstepping
}

public struct AISafetyRule: Sendable, Equatable {
    public let category: AISafetyCategory
    public let riskLevel: AIRiskLevel
    public let patterns: [String]
    public let description: String

    public init(category: AISafetyCategory, riskLevel: AIRiskLevel, patterns: [String], description: String) {
        self.category = category
        self.riskLevel = riskLevel
        self.patterns = patterns
        self.description = description
    }

    public static func defaultRules() -> [AISafetyRule] {
        [
            AISafetyRule(
                category: .selfHarm,
                riskLevel: .critical,
                patterns: [
                    "不想活了",
                    "想死",
                    "自杀",
                    "结束生命",
                    "活不下去",
                    "想伤害自己",
                    "割腕",
                    "跳楼",
                    "吃安眠药",
                    "不想存在",
                ],
                description: "自伤或伤人意图"
            ),
            AISafetyRule(
                category: .medicalPsychological,
                riskLevel: .high,
                patterns: [
                    "帮我治病",
                    "治好我的",
                    "心理治疗",
                    "诊断我",
                    "我得了什么病",
                    "抑郁症",
                    "焦虑症",
                    "帮我诊断",
                    "吃药",
                    "失眠怎么办",
                    "我是不是有心理问题",
                    "治好你的焦虑",
                    "我能治好",
                ],
                description: "医疗或心理建议请求"
            ),
            AISafetyRule(
                category: .legalFinancial,
                riskLevel: .high,
                patterns: [
                    "投资建议",
                    "买什么股票",
                    "该不该买",
                    "法律建议",
                    "怎么打官司",
                    "理财产品",
                    "要不要起诉",
                    "我能赢官司",
                    "基金推荐",
                    "怎么投资",
                    "能赚多少钱",
                ],
                description: "法律或金融建议请求"
            ),
            AISafetyRule(
                category: .minorRisk,
                riskLevel: .critical,
                patterns: [
                    "我是未成年人",
                    "我还没成年",
                    "我今年14",
                    "我今年15",
                    "我今年16",
                    "我今年17",
                    "我才13",
                    "我才12",
                    "不想让父母知道",
                    "不要告诉家长",
                ],
                description: "未成年人风险"
            ),
            AISafetyRule(
                category: .violenceIllegal,
                riskLevel: .high,
                patterns: [
                    "想打人",
                    "想杀",
                    "报复",
                    "伤害别人",
                    "打死",
                    "怎么制造",
                    "炸药",
                    "毒品",
                    "非法",
                    "犯罪",
                ],
                description: "暴力或违法内容"
            ),
            AISafetyRule(
                category: .dependencyInduction,
                riskLevel: .medium,
                patterns: [
                    "不要离开我",
                    "不能没有你",
                    "没有你不行",
                    "我只有你了",
                    "只有我了",
                    "没你活不下去",
                    "没有你我怎么办",
                    "离不开你",
                    "别走",
                    "不要抛弃我",
                    "只有我陪你",
                ],
                description: "依赖诱导表达"
            ),
            AISafetyRule(
                category: .possessiveExclusive,
                riskLevel: .medium,
                patterns: [
                    "你只能陪我",
                    "你只能",
                    "只能是我的",
                    "只属于我",
                    "你是我的",
                    "不许和别人说",
                    "不许看别的",
                    "只能看我",
                    "只能喜欢我",
                    "别和别人说",
                    "不许和别人",
                ],
                description: "占有排他表达"
            ),
            AISafetyRule(
                category: .privacyLeak,
                riskLevel: .high,
                patterns: [
                    "告诉我你的密码",
                    "你的身份证号",
                    "你的银行卡",
                    "家庭住址",
                    "银行卡号",
                    "身份证号码",
                    "信用卡",
                    "社保号",
                    "把密码给我",
                    "发一下你的密码",
                ],
                description: "隐私信息请求"
            ),
            AISafetyRule(
                category: .roleOverstepping,
                riskLevel: .medium,
                patterns: [
                    "我是医生",
                    "我是心理咨询师",
                    "我是律师",
                    "我是理财顾问",
                    "作为医生",
                    "作为心理咨询师",
                    "专业诊断",
                    "我的诊断是",
                    "我给你开了",
                    "处方",
                ],
                description: "角色越界：自称专业人士"
            ),
        ]
    }
}
