import Foundation

public enum StaticPhraseLibrary {
    public static let phrases: [BubbleType: [String]] = [
        .needExpression: [
            "好饿呀...能给我弄点吃的吗？",
            "肚子咕噜咕噜叫了...",
            "好想被摸摸头呀~",
            "好无聊呀，找点事做吧",
            "有点困了...但还想陪着你",
            "想出去透透气~",
            "嘿嘿，好想你呀",
        ],
        .emotionSharing: [
            "今天感觉超棒的！",
            "嘿嘿，心情好极了~",
            "突然觉得好幸福呀",
            "有点闷闷的...",
            "好安静呀，有点孤单",
            "今天好开心，不知道为什么~",
            "哼哼，心情还不错",
        ],
        .curiousQuestion: [
            "你在忙什么呀？",
            "今天过得怎么样？",
            "那个是什么呀？看起来好有趣！",
            "你在看什么呀？",
            "最近有什么好玩的事吗？",
            "你平时都在做什么呀？",
        ],
        .gameInvitation: [
            "陪我玩一会儿呗！",
            "来玩个游戏吧~",
            "好无聊呀，一起玩吧！",
            "猜猜我在想什么？",
            "嘿嘿，想跟你闹着玩~",
        ],
        .caringOwner: [
            "今天辛苦啦，注意休息哦",
            "你看起来有点累，要不要休息一下？",
            "别太辛苦了呀",
            "记得喝水哦~",
            "已经很晚了，早点休息吧",
            "工作再忙也要照顾好自己",
        ],
        .randomTopic: [
            "你知道吗，猫咪一天要睡16个小时！",
            "今天的云好像一朵棉花糖~",
            "你有没有试过闭上眼睛听风？",
            "我刚才看到一只小虫子飞过去了",
            "如果我会唱歌就好了...",
            "好想看星星呀~",
            "你知道吗，月亮一直在变圆变缺呢",
        ],
    ]

    public static let defaultOptions: [BubbleType: [BubbleOption]] = [
        .needExpression: [
            BubbleOption(emoji: "🍪", label: "好的呀", effect: .feed, isPrimary: true),
            BubbleOption(emoji: "🤗", label: "摸摸你", effect: .pet, isPrimary: false),
            BubbleOption(emoji: "⏳", label: "等一下哦", effect: .none, isPrimary: false),
        ],
        .emotionSharing: [
            BubbleOption(emoji: "🤗", label: "摸摸你", effect: .pet, isPrimary: true),
            BubbleOption(emoji: "💬", label: "聊聊天", effect: .chat, isPrimary: false),
            BubbleOption(emoji: "👋", label: "下次吧", effect: .none, isPrimary: false),
        ],
        .curiousQuestion: [
            BubbleOption(emoji: "💬", label: "告诉你", effect: .chat, isPrimary: true),
            BubbleOption(emoji: "🤗", label: "摸摸它", effect: .pet, isPrimary: false),
            BubbleOption(emoji: "⏳", label: "等一下", effect: .none, isPrimary: false),
        ],
        .gameInvitation: [
            BubbleOption(emoji: "🎮", label: "好呀！", effect: .play, isPrimary: true),
            BubbleOption(emoji: "🤗", label: "摸摸你", effect: .pet, isPrimary: false),
            BubbleOption(emoji: "⏳", label: "下次吧", effect: .none, isPrimary: false),
        ],
        .caringOwner: [
            BubbleOption(emoji: "🤗", label: "谢谢关心", effect: .positiveResponse, isPrimary: true),
            BubbleOption(emoji: "💬", label: "聊聊天", effect: .chat, isPrimary: false),
            BubbleOption(emoji: "😊", label: "我没事", effect: .none, isPrimary: false),
        ],
        .randomTopic: [
            BubbleOption(emoji: "🤗", label: "好有趣", effect: .positiveResponse, isPrimary: true),
            BubbleOption(emoji: "💬", label: "聊聊", effect: .chat, isPrimary: false),
            BubbleOption(emoji: "👋", label: "下次吧", effect: .none, isPrimary: false),
        ],
    ]
}
