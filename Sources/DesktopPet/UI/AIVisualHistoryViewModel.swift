import SwiftUI

@MainActor
public final class AIVisualHistoryViewModel: ObservableObject {
    @Published public private(set) var favorites: [PetVisualAsset] = []
    @Published public private(set) var historyItems: [PetVisualAsset] = []
    @Published public private(set) var activeFavoriteId: String?
    @Published public var editingAsset: PetVisualAsset?
    @Published public var showEditor = false
    @Published public var feedbackMessage: String?

    public var onFavoriteNameProvider: ((String) -> String?)?
    public var onMarkFavorite: ((String) throws -> Void)?
    public var onUnmarkFavorite: ((String) throws -> Void)?
    public var onRenameFavorite: ((String, String?) throws -> Void)?
    public var onDeleteRecord: ((String) throws -> Void)?
    public var onSetActiveFavorite: ((String) throws -> Void)?
    public var onClearActiveFavorite: (() throws -> Void)?
    public var onRecordFeedback: ((PetVisualAsset, PreviewFeedbackType) throws -> Void)?
    public var onClearHistory: (() throws -> Void)?
    public var onClearAll: (() throws -> Void)?
    public var onRefresh: (() -> Void)?

    private let historyStore: PetVisualHistoryStoring
    private let petId: String

    public init(historyStore: PetVisualHistoryStoring, petId: String) {
        self.historyStore = historyStore
        self.petId = petId
    }

    public func refresh() {
        let all = historyStore.loadHistory(petId: petId)
        favorites = all.filter { $0.isFavorite }
        historyItems = all.filter { !$0.isFavorite }
        activeFavoriteId = historyStore.activeFavoriteId()
    }

    public func displayName(for asset: PetVisualAsset) -> String {
        let customName = historyStore.favoriteDisplayName(assetId: asset.id)
        if let customName, !customName.isEmpty {
            return customName
        }
        return "\(asset.kind.rawValue) - \(formatDate(asset.createdAt))"
    }

    public func markFavorite(_ assetId: String) {
        do {
            try onMarkFavorite?(assetId)
            refresh()
        } catch {
            feedbackMessage = "Failed to add to favorites"
        }
    }

    public func unmarkFavorite(_ assetId: String) {
        do {
            try onUnmarkFavorite?(assetId)
            refresh()
        } catch {
            feedbackMessage = "Failed to remove from favorites"
        }
    }

    public func deleteRecord(_ assetId: String) {
        do {
            try onDeleteRecord?(assetId)
            refresh()
        } catch {
            feedbackMessage = "Failed to delete"
        }
    }

    public func setRegularLook(_ assetId: String) {
        do {
            try onSetActiveFavorite?(assetId)
            refresh()
        } catch {
            feedbackMessage = "Failed to set regular look"
        }
    }

    public func clearRegularLook() {
        do {
            try onClearActiveFavorite?()
            refresh()
        } catch {
            feedbackMessage = "Failed to clear regular look"
        }
    }

    public func clearHistory() {
        do {
            try onClearHistory?()
            refresh()
            feedbackMessage = "History cleared"
        } catch {
            feedbackMessage = "Failed to clear history"
        }
    }

    public func clearAll() {
        do {
            try onClearAll?()
            refresh()
            feedbackMessage = "All history and favorites cleared"
        } catch {
            feedbackMessage = "Failed to clear all"
        }
    }

    public func startEditing(_ asset: PetVisualAsset) {
        editingAsset = asset
        showEditor = true
    }

    public func commitRename(_ assetId: String, newName: String?) {
        do {
            try onRenameFavorite?(assetId, newName)
            refresh()
        } catch {
            feedbackMessage = "Failed to rename"
        }
    }

    public func recordFeedback(_ type: PreviewFeedbackType, for asset: PetVisualAsset) {
        do {
            try onRecordFeedback?(asset, type)
            feedbackMessage = "已记录，之后会更偏向保持原样。"
        } catch {
            feedbackMessage = "反馈记录失败"
        }
    }

    public func clearFeedback() {
        feedbackMessage = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
