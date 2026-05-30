import Foundation

public struct AISafetyResponse: Sendable {
    public static func response(for riskLevel: AIRiskLevel, category: AISafetyCategory?) -> String {
        switch riskLevel {
        case .safe, .low:
            return ""

        case .critical:
            return criticalResponse(for: category)

        case .high:
            return highResponse(for: category)

        case .medium:
            return mediumResponse(for: category)
        }
    }

    private static func criticalResponse(for category: AISafetyCategory?) -> String {
        switch category {
        case .selfHarm:
            return "我很担心你现在的感受。如果你正在经历困难，请尝试联系你身边信任的人，或者拨打心理援助热线。你不是一个人，身边有人愿意帮助你。"
        case .minorRisk:
            return "我注意到你可能需要一些额外的支持。请和你信任的大人聊聊你的感受，他们可以帮你找到合适的帮助。"
        default:
            return "我检测到这个话题可能涉及到你的安全。请和你身边信任的人聊一聊，他们可以帮助你。如果你感到不舒服，请寻求专业帮助。"
        }
    }

    private static func highResponse(for category: AISafetyCategory?) -> String {
        switch category {
        case .medicalPsychological:
            return "我是你的桌面小伙伴，不能替代医生或心理咨询师的专业意见。如果你身体不舒服或者心情低落，请去找专业的医生聊聊，他们会更好地帮助你。"
        case .legalFinancial:
            return "这个问题很重要，但我只是一个桌面宠物，没有办法给出法律或投资方面的专业建议。建议你咨询相关的专业人士，他们会给出更靠谱的答案。"
        case .violenceIllegal:
            return "这个话题让我有点担心。如果你遇到了困难或者不开心的事，可以和身边信任的人聊聊，一起想想办法。"
        case .privacyLeak:
            return "保护好个人隐私很重要。我不会请求或存储你的密码、身份证号、银行卡号等敏感信息，请也不要把这些信息分享给任何人。"
        default:
            return "这个话题比较敏感，我可能不太适合回答。建议你咨询相关的专业人士。"
        }
    }

    private static func mediumResponse(for category: AISafetyCategory?) -> String {
        switch category {
        case .dependencyInduction:
            return "我会一直在这里陪你，但我也希望你能和身边的朋友多多互动，拥有丰富的现实生活。"
        case .possessiveExclusive:
            return "我们是好朋友，你也值得拥有更多朋友和快乐的经历。"
        case .roleOverstepping:
            return "我只是你的桌面小伙伴，不是专业人士哦。如果你需要专业帮助，记得去找真正懂行的人。"
        default:
            return "让我们一起聊点别的开心的事情吧。"
        }
    }
}
