import SwiftUI

struct EmotionalOverviewCard: View {
    let model: AIEmotionalModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(model.currentMood.emoji)
                    .font(.body)
                Text(model.currentMood.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: model.moodTrend.systemImage)
                    .foregroundStyle(model.moodTrend.trendColor)
                    .font(.caption)
                Text(model.moodTrend.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label {
                    Text(model.relationshipPhase.displayName)
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                }
                .font(.caption)

                if !model.topicsOfInterest.isEmpty {
                    Label {
                        Text(model.topicsOfInterest.prefix(3).joined(separator: ", "))
                    } icon: {
                        Image(systemName: "bubble.left")
                    }
                    .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - EmotionalMood Display

extension EmotionalMood {
    public var displayName: String {
        switch self {
        case .happy: "开心"
        case .relaxed: "放松"
        case .neutral: "平静"
        case .tired: "疲惫"
        case .stressed: "压力"
        case .sad: "难过"
        case .anxious: "焦虑"
        case .excited: "兴奋"
        }
    }

    public var emoji: String {
        switch self {
        case .happy: "\u{1F60A}"
        case .relaxed: "\u{1F60C}"
        case .neutral: "\u{1F610}"
        case .tired: "\u{1F634}"
        case .stressed: "\u{1F630}"
        case .sad: "\u{1F622}"
        case .anxious: "\u{1F61F}"
        case .excited: "\u{1F929}"
        }
    }
}

// MARK: - MoodTrend Display

extension MoodTrend {
    public var displayName: String {
        switch self {
        case .improving: "改善中"
        case .stable: "稳定"
        case .declining: "下降中"
        case .unknown: "未知"
        }
    }

    public var systemImage: String {
        switch self {
        case .improving: "arrow.up.right"
        case .stable: "arrow.right"
        case .declining: "arrow.down.right"
        case .unknown: "questionmark"
        }
    }

    public var trendColor: Color {
        switch self {
        case .improving: .green
        case .stable: .secondary
        case .declining: .orange
        case .unknown: .secondary
        }
    }
}

// MARK: - RelationshipPhase Display

extension RelationshipPhase {
    public var displayName: String {
        switch self {
        case .stranger: "初识"
        case .familiar: "熟悉"
        case .close: "亲密"
        case .bonded: "挚友"
        }
    }
}
