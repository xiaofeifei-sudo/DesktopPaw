import Foundation

public struct AIVisualActionPackBridge: Sendable {
    private let draftBuilder: ActionPackDraftBuilder

    public init(draftBuilder: ActionPackDraftBuilder = ActionPackDraftBuilder()) {
        self.draftBuilder = draftBuilder
    }

    public func createDraft(
        from asset: PetVisualAsset,
        displayName: String,
        targetFrameSize: CGSizeCodable,
        prompt: String? = nil,
        model: String? = nil,
        seed: String? = nil,
        notes: String? = nil,
        frameDurationMs: Int = 160,
        loop: Bool = false,
        gridOverride: (columns: Int, rows: Int)? = nil
    ) throws -> ActionPackDraft {
        let imageData = try Data(contentsOf: asset.localURL)

        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: asset.createdAt,
            provider: asset.providerId,
            model: model,
            prompt: prompt,
            seed: seed,
            notes: notes ?? "Kind: \(asset.kind.rawValue)"
        )

        return try draftBuilder.buildDraft(
            input: .singleImage(imageData),
            displayName: displayName,
            targetFrameSize: targetFrameSize,
            frameDurationMs: frameDurationMs,
            loop: loop,
            gridOverride: gridOverride,
            source: .aiGeneration,
            sourceMetadata: metadata
        )
    }

    public func createRegenerationDraft(
        originalSource: ActionPackSourceMetadata,
        newImageData: Data,
        displayName: String,
        targetFrameSize: CGSizeCodable,
        frameDurationMs: Int = 160,
        loop: Bool = false,
        gridOverride: (columns: Int, rows: Int)? = nil
    ) throws -> ActionPackDraft {
        let metadata = ActionPackSourceMetadata(
            source: .aiGeneration,
            createdAt: Date(),
            provider: originalSource.provider,
            model: originalSource.model,
            prompt: originalSource.prompt,
            seed: originalSource.seed,
            notes: "Regenerated from previous version"
        )

        return try draftBuilder.buildDraft(
            input: .singleImage(newImageData),
            displayName: displayName,
            targetFrameSize: targetFrameSize,
            frameDurationMs: frameDurationMs,
            loop: loop,
            gridOverride: gridOverride,
            source: .aiGeneration,
            sourceMetadata: metadata
        )
    }
}
