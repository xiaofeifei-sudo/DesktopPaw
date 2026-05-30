import Foundation

public struct BubblePhraseCatalogBuilder {
    public init() {}

    public func build(
        from profile: BubbleProfile?,
        defaultCatalog: BubblePhraseCatalog? = nil
    ) -> BubblePhraseCatalog {
        let defaults = defaultCatalog ?? Self.defaultCatalog()
        guard let profile else {
            return defaults
        }
        let legacy = convertLegacyProfile(profile)
        return defaults.merging(with: legacy)
    }

    public func convertLegacyProfile(_ profile: BubbleProfile) -> BubblePhraseCatalog {
        var phrases: [BubblePhrase] = []
        for (trigger, texts) in profile.phrases {
            for (index, text) in texts.enumerated() {
                let id = "legacy_\(trigger.rawValue)_\(index)"
                let phrase = BubblePhrase(
                    id: id,
                    text: text,
                    triggers: [trigger],
                    priority: Self.defaultPriority(for: trigger)
                )
                phrases.append(phrase)
            }
        }
        return BubblePhraseCatalog(phrases: phrases)
    }

    static func defaultPriority(for trigger: BubbleTrigger) -> BubblePriority {
        switch trigger {
        case .clicked, .pet, .feed:
            return .interaction
        case .hungry, .tired, .happy:
            return .state
        case .idle, .walking, .sleeping:
            return .ambient
        case .dailyGreeting, .longAbsenceReturn, .relationshipLevelUp:
            return .relationship
        case .actionLine:
            return .ambient
        case .microDialogPrompt:
            return .relationship
        case .quietModeNotice:
            return .state
        }
    }
}

extension BubblePhraseCatalogBuilder {
    public static func defaultCatalog() -> BubblePhraseCatalog {
        BubblePhraseCatalog(phrases: defaultPhrases())
    }

    // swiftlint:disable:next function_body_length
    public static func defaultPhrases() -> [BubblePhrase] {
        var phrases: [BubblePhrase] = []
        let id = { (trigger: BubbleTrigger, index: Int) in "default_\(trigger.rawValue)_\(index)" }

        // MARK: - clicked
        phrases += [
            BubblePhrase(id: id(.clicked, 0), text: "嘿", triggers: [.clicked], priority: .interaction),
            BubblePhrase(id: id(.clicked, 1), text: "嗨", triggers: [.clicked], priority: .interaction),
            BubblePhrase(id: id(.clicked, 2), text: "你好呀", triggers: [.clicked], priority: .interaction),
            BubblePhrase(id: id(.clicked, 3), text: "在呢", triggers: [.clicked], priority: .interaction),
        ]

        // MARK: - pet
        phrases += [
            BubblePhrase(id: id(.pet, 0), text: "开心", triggers: [.pet], priority: .interaction),
            BubblePhrase(id: id(.pet, 1), text: "再摸摸", triggers: [.pet], priority: .interaction),
            BubblePhrase(id: id(.pet, 2), text: "嘿嘿", triggers: [.pet], priority: .interaction),
            BubblePhrase(id: id(.pet, 3), text: "好舒服", triggers: [.pet], priority: .interaction),
            BubblePhrase(id: id(.pet, 4), text: "喜欢", triggers: [.pet], priority: .interaction),
        ]

        // MARK: - feed
        phrases += [
            BubblePhrase(id: id(.feed, 0), text: "好吃", triggers: [.feed], priority: .interaction),
            BubblePhrase(id: id(.feed, 1), text: "满足了", triggers: [.feed], priority: .interaction),
            BubblePhrase(id: id(.feed, 2), text: "谢谢", triggers: [.feed], priority: .interaction),
            BubblePhrase(id: id(.feed, 3), text: "饱了", triggers: [.feed], priority: .interaction),
        ]

        // MARK: - hungry
        phrases += [
            BubblePhrase(id: id(.hungry, 0), text: "有点饿", triggers: [.hungry], priority: .state, canStartMicroDialog: true),
            BubblePhrase(id: id(.hungry, 1), text: "想吃点东西", triggers: [.hungry], priority: .state, canStartMicroDialog: true),
            BubblePhrase(id: id(.hungry, 2), text: "饿了", triggers: [.hungry], priority: .state, canStartMicroDialog: true),
        ]

        // MARK: - tired
        phrases += [
            BubblePhrase(id: id(.tired, 0), text: "困了", triggers: [.tired], priority: .state, canStartMicroDialog: true),
            BubblePhrase(id: id(.tired, 1), text: "想眯一会儿", triggers: [.tired], priority: .state, canStartMicroDialog: true),
            BubblePhrase(id: id(.tired, 2), text: "有点累", triggers: [.tired], priority: .state),
        ]

        // MARK: - happy
        phrases += [
            BubblePhrase(id: id(.happy, 0), text: "开心", triggers: [.happy], priority: .state),
            BubblePhrase(id: id(.happy, 1), text: "心情不错", triggers: [.happy], priority: .state),
            BubblePhrase(id: id(.happy, 2), text: "耶", triggers: [.happy], priority: .state),
        ]

        // MARK: - idle
        phrases += [
            BubblePhrase(id: id(.idle, 0), text: "陪你一会儿", triggers: [.idle], priority: .ambient),
            BubblePhrase(id: id(.idle, 1), text: "在呢", triggers: [.idle], priority: .ambient),
            BubblePhrase(id: id(.idle, 2), text: "嗯", triggers: [.idle], priority: .ambient),
            BubblePhrase(id: id(.idle, 3), text: "发呆中", triggers: [.idle], priority: .ambient),
        ]

        // MARK: - walking
        phrases += [
            BubblePhrase(id: id(.walking, 0), text: "走走", triggers: [.walking], priority: .ambient),
            BubblePhrase(id: id(.walking, 1), text: "溜达", triggers: [.walking], priority: .ambient),
            BubblePhrase(id: id(.walking, 2), text: "逛逛", triggers: [.walking], priority: .ambient),
        ]

        // MARK: - sleeping
        phrases += [
            BubblePhrase(id: id(.sleeping, 0), text: "zzz", triggers: [.sleeping], priority: .ambient),
            BubblePhrase(id: id(.sleeping, 1), text: "呼噜噜", triggers: [.sleeping], priority: .ambient),
        ]

        // MARK: - dailyGreeting
        phrases += [
            BubblePhrase(id: id(.dailyGreeting, 0), text: "早上好", triggers: [.dailyGreeting], timeTags: [.morning], priority: .relationship),
            BubblePhrase(id: id(.dailyGreeting, 1), text: "今天也在", triggers: [.dailyGreeting], priority: .relationship),
            BubblePhrase(id: id(.dailyGreeting, 2), text: "又见面啦", triggers: [.dailyGreeting], priority: .relationship),
            BubblePhrase(id: id(.dailyGreeting, 3), text: "下午好", triggers: [.dailyGreeting], timeTags: [.afternoon], priority: .relationship),
            BubblePhrase(id: id(.dailyGreeting, 4), text: "晚上好", triggers: [.dailyGreeting], timeTags: [.evening], priority: .relationship),
        ]

        // MARK: - longAbsenceReturn
        phrases += [
            BubblePhrase(id: id(.longAbsenceReturn, 0), text: "又见面啦", triggers: [.longAbsenceReturn], priority: .relationship),
            BubblePhrase(id: id(.longAbsenceReturn, 1), text: "欢迎回来", triggers: [.longAbsenceReturn], priority: .relationship),
            BubblePhrase(id: id(.longAbsenceReturn, 2), text: "今天也在", triggers: [.longAbsenceReturn], priority: .relationship),
            BubblePhrase(id: id(.longAbsenceReturn, 3), text: "好久不见", triggers: [.longAbsenceReturn], priority: .relationship),
        ]

        // MARK: - relationshipLevelUp
        phrases += [
            BubblePhrase(id: id(.relationshipLevelUp, 0), text: "更亲近了", triggers: [.relationshipLevelUp], priority: .relationship),
            BubblePhrase(id: id(.relationshipLevelUp, 1), text: "开心", triggers: [.relationshipLevelUp], priority: .relationship),
            BubblePhrase(id: id(.relationshipLevelUp, 2), text: "好喜欢你", triggers: [.relationshipLevelUp], minRelationshipLevel: .familiar, priority: .relationship),
        ]

        // MARK: - actionLine
        phrases += [
            BubblePhrase(id: id(.actionLine, 0), text: "好看吧", triggers: [.actionLine], priority: .ambient),
            BubblePhrase(id: id(.actionLine, 1), text: "怎么样", triggers: [.actionLine], priority: .ambient),
        ]

        // MARK: - microDialogPrompt
        phrases += [
            BubblePhrase(id: id(.microDialogPrompt, 0), text: "你忙完了吗？", triggers: [.microDialogPrompt], priority: .relationship, canStartMicroDialog: true),
            BubblePhrase(id: id(.microDialogPrompt, 1), text: "想聊会儿吗", triggers: [.microDialogPrompt], minRelationshipLevel: .familiar, priority: .relationship, canStartMicroDialog: true),
        ]

        // MARK: - quietModeNotice
        phrases += [
            BubblePhrase(id: id(.quietModeNotice, 0), text: "安静模式", triggers: [.quietModeNotice], priority: .state),
        ]

        // MARK: - Relationship-level exclusive phrases
        phrases += [
            // Lv.2 familiar+
            BubblePhrase(id: "rel_familiar_idle_0", text: "有你在真好", triggers: [.idle], minRelationshipLevel: .familiar, priority: .ambient),
            BubblePhrase(id: "rel_familiar_pet_0", text: "嘿嘿嘿", triggers: [.pet], minRelationshipLevel: .familiar, priority: .interaction),
            // Lv.3 close+
            BubblePhrase(id: "rel_close_idle_0", text: "陪着你", triggers: [.idle], minRelationshipLevel: .close, priority: .ambient),
            BubblePhrase(id: "rel_close_pet_0", text: "最开心了", triggers: [.pet], minRelationshipLevel: .close, priority: .interaction),
            BubblePhrase(id: "rel_close_greeting_0", text: "想你了", triggers: [.dailyGreeting], minRelationshipLevel: .close, priority: .relationship),
            // Lv.4 trusted+
            BubblePhrase(id: "rel_trusted_idle_0", text: "一直在这儿", triggers: [.idle], minRelationshipLevel: .trusted, priority: .ambient),
            BubblePhrase(id: "rel_trusted_return_0", text: "终于等到你", triggers: [.longAbsenceReturn], minRelationshipLevel: .trusted, priority: .relationship),
            // Lv.5 bonded
            BubblePhrase(id: "rel_bonded_idle_0", text: "默契", triggers: [.idle], minRelationshipLevel: .bonded, priority: .ambient),
            BubblePhrase(id: "rel_bonded_pet_0", text: "不用说话也知道", triggers: [.pet], minRelationshipLevel: .bonded, priority: .interaction),
        ]

        return phrases
    }
}
