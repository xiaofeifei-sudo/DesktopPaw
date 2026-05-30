import Foundation

public enum AssetLifecycleState: String, Codable, Sendable, Equatable {
    case generatedPendingPreview
    case applied
    case discardedByUser
    case rejectedByGate
    case expired
    case restored
}

public protocol AssetLifecycleManaging: Sendable {
    func transition(asset: PetVisualAsset, to state: AssetLifecycleState) async throws
    func currentState(for assetId: String, petId: String) async -> AssetLifecycleState
    func pendingPreviewAssets(for petId: String) async -> [PetVisualAsset]
    func appliedAsset(for petId: String) async -> PetVisualAsset?
    func canRestore(for petId: String) async -> Bool
}

public final class AssetLifecycleManager: AssetLifecycleManaging, @unchecked Sendable {
    private let assetStore: PetVisualAssetStoring

    public init(assetStore: PetVisualAssetStoring) {
        self.assetStore = assetStore
    }

    private static let validTransitions: [AssetLifecycleState: Set<AssetLifecycleState>] = [
        .generatedPendingPreview: [.applied, .discardedByUser],
        .applied: [.restored, .expired],
    ]

    public func transition(asset: PetVisualAsset, to state: AssetLifecycleState) async throws {
        let allowed = Self.validTransitions[asset.lifecycleState] ?? []
        guard allowed.contains(state) else { return }

        try assetStore.updateAsset(id: asset.id, petId: asset.petId) { a in
            a.lifecycleState = state
        }
    }

    public func currentState(for assetId: String, petId: String) async -> AssetLifecycleState {
        assetStore.loadAsset(id: assetId, petId: petId)?.lifecycleState ?? .applied
    }

    public func pendingPreviewAssets(for petId: String) async -> [PetVisualAsset] {
        assetStore.loadAllAssets(petId: petId)
            .filter { $0.lifecycleState == .generatedPendingPreview }
    }

    public func appliedAsset(for petId: String) async -> PetVisualAsset? {
        assetStore.loadAllAssets(petId: petId)
            .first { $0.lifecycleState == .applied }
    }

    public func canRestore(for petId: String) async -> Bool {
        assetStore.loadAllAssets(petId: petId)
            .contains { $0.lifecycleState == .applied }
    }
}
