import Foundation
import DesktopPet

@MainActor
func runAIVisualHistoryViewModelTests() {
    let tests = AIVisualHistoryViewModelTests()
    tests.recordFeedbackFromHistoryInvokesCallbackWithAssetAndType()
    tests.recordFeedbackFromHistoryShowsNeutralMessage()
    tests.recordFeedbackFailureShowsNonTechnicalMessage()
}

@MainActor
private struct AIVisualHistoryViewModelTests {
    func recordFeedbackFromHistoryInvokesCallbackWithAssetAndType() {
        let asset = makeAsset(id: "asset-1", petId: "pet-1")
        let model = makeModel(assets: [asset])
        var captured: (assetId: String, type: PreviewFeedbackType)?
        model.onRecordFeedback = { asset, type in
            captured = (asset.id, type)
        }

        model.recordFeedback(.notLikeOriginal, for: asset)

        expect(captured?.assetId == "asset-1", "feedback callback should receive selected asset")
        expect(captured?.type == .notLikeOriginal, "feedback callback should receive selected feedback type")
    }

    func recordFeedbackFromHistoryShowsNeutralMessage() {
        let asset = makeAsset(id: "asset-2", petId: "pet-1")
        let model = makeModel(assets: [asset])
        model.onRecordFeedback = { _, _ in }

        model.recordFeedback(.colorWrong, for: asset)

        expect(
            model.feedbackMessage == "已记录，之后会更偏向保持原样。",
            "feedback success should use neutral product copy"
        )
    }

    func recordFeedbackFailureShowsNonTechnicalMessage() {
        let asset = makeAsset(id: "asset-3", petId: "pet-1")
        let model = makeModel(assets: [asset])
        model.onRecordFeedback = { _, _ in throw TestError.feedbackFailed }

        model.recordFeedback(.styleWrong, for: asset)

        expect(model.feedbackMessage == "反馈记录失败", "feedback failure should use short non-technical copy")
    }

    private func makeModel(assets: [PetVisualAsset]) -> AIVisualHistoryViewModel {
        let store = StubVisualHistoryStore(assets: assets)
        let model = AIVisualHistoryViewModel(historyStore: store, petId: "pet-1")
        model.refresh()
        return model
    }

    private func makeAsset(id: String, petId: String) -> PetVisualAsset {
        PetVisualAsset(
            id: id,
            petId: petId,
            actionId: id,
            providerId: "mock",
            localURL: URL(fileURLWithPath: "/tmp/\(id).png"),
            promptDigest: "digest-\(id)",
            kind: .ambience,
            renderMode: .replaceWholeImage,
            lifecycleState: .applied
        )
    }
}

private enum TestError: Error {
    case feedbackFailed
}

private final class StubVisualHistoryStore: PetVisualHistoryStoring, @unchecked Sendable {
    private var assets: [PetVisualAsset]

    init(assets: [PetVisualAsset]) {
        self.assets = assets
    }

    func loadHistory(petId: String) -> [PetVisualAsset] {
        assets.filter { $0.petId == petId && !$0.isFavorite }
    }

    func loadFavorites(petId: String) -> [PetVisualAsset] {
        assets.filter { $0.petId == petId && $0.isFavorite }
    }

    func markFavorite(assetId: String, petId: String) throws {}
    func unmarkFavorite(assetId: String, petId: String) throws {}
    func renameFavorite(assetId: String, petId: String, name: String?) throws {}
    func deleteRecord(assetId: String, petId: String) throws {}
    func setActiveFavorite(assetId: String, petId: String) throws {}
    func clearActiveFavorite(petId: String) throws {}
    func clearHistory(petId: String) throws {}
    func clearAll(petId: String) throws {}
    func favoriteDisplayName(assetId: String) -> String? { nil }
    func activeFavoriteId() -> String? { nil }
}
