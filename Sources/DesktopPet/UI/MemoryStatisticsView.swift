import SwiftUI

struct MemoryStatisticsView: View {
    let statistics: MemoryStatistics
    let emotionalModel: AIEmotionalModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Statistics")
                .font(.headline)

            capacitySection
            Divider()
            categoryBreakdown

            if let model = emotionalModel {
                Divider()
                Text("Emotional Overview")
                    .font(.subheadline.weight(.medium))
                EmotionalOverviewCard(model: model)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: emotionalModel != nil ? 520 : 400)
    }

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Capacity")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                ProgressView(value: statistics.utilizationRate)
                    .progressViewStyle(.linear)
                Text("\(statistics.totalCount)/\(statistics.capacity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }

            Text(String(format: "%.0f%% used", statistics.utilizationRate * 100))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category Breakdown")
                .font(.subheadline.weight(.medium))

            let sortedCategories = MemoryManagementViewModel.categoryDisplayOrder
            ForEach(sortedCategories, id: \.self) { category in
                let count = statistics.categoryCounts[category] ?? 0
                if count > 0 {
                    HStack(spacing: 8) {
                        Text(category.displayName)
                            .font(.caption)
                            .frame(width: 50, alignment: .leading)
                        Capsule()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: max(CGFloat(count) / CGFloat(max(statistics.totalCount, 1)) * 120, 4), height: 6)
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
        }
    }
}
