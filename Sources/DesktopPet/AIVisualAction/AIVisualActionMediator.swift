import AppKit
import Foundation

@MainActor
public protocol AIVisualActionMediating: AnyObject {
    func handleCandidates(from response: AIChatResponse, petId: String)
    func requestManualGeneration(petId: String, petName: String)
    func confirmAction(requestId: String)
    func rejectAction(requestId: String)
    func restoreVisual()
}

@MainActor
public final class AIVisualActionMediator: AIVisualActionMediating {
    private let coordinator: AIVisualActionCoordinator
    private let generationService: VisualGenerationServicing
    private let assetStore: PetVisualAssetStoring
    private let stateController: PetVisualStateControlling
    private let safetyService: AIVisualSafetyServicing
    private let quotaStore: AIVisualQuotaStoring
    private let preferencesStore: AIVisualPreferencesStoring
    private let visualPreferenceStore: PetVisualPreferenceStoring?
    private let diagnosticsStore: AIVisualDiagnosticsStoring?
    private let generationDiagnosticsRecorder: GenerationDiagnosticsRecording?
    private let petIdentityDescriber: PetIdentityDescribing?
    private let promptStrategy: PromptStrategizing?
    private let referenceImageProvider: PetReferenceImageProviding
    private let referenceImagePipeline: ReferenceImageProcessing?
    private let qualityGateChecker: QualityGateChecking?
    private let lifecycleManager: AssetLifecycleManaging?
    private let feedbackStore: UserFeedbackRecording?
    private let getReferenceImage: @MainActor () -> NSImage?
    private let hasActiveOverlayProvider: @MainActor () -> Bool
    private weak var viewModel: PetViewModel?

    public var onConfirmationRequested: ((AIVisualConfirmationRequest) -> Void)?
    public var onVisualChanged: ((String) -> Void)?
    public var onVisualRestored: (() -> Void)?
    public var onPolicyDenied: ((String?) -> Void)?
    public var onGenerationFailed: ((String) -> Void)?
    public var onPreviewRequested: ((PetVisualAsset, URL) -> Void)?
    public var onGateRejected: ((PetVisualAsset, String) -> Void)?

    public init(
        coordinator: AIVisualActionCoordinator,
        generationService: VisualGenerationServicing,
        assetStore: PetVisualAssetStoring,
        stateController: PetVisualStateControlling,
        safetyService: AIVisualSafetyServicing,
        quotaStore: AIVisualQuotaStoring,
        preferencesStore: AIVisualPreferencesStoring,
        visualPreferenceStore: PetVisualPreferenceStoring? = nil,
        diagnosticsStore: AIVisualDiagnosticsStoring? = nil,
        generationDiagnosticsRecorder: GenerationDiagnosticsRecording? = nil,
        petIdentityDescriber: PetIdentityDescribing? = nil,
        promptStrategy: PromptStrategizing? = nil,
        referenceImageProvider: PetReferenceImageProviding,
        referenceImagePipeline: ReferenceImageProcessing? = nil,
        qualityGateChecker: QualityGateChecking? = nil,
        lifecycleManager: AssetLifecycleManaging? = nil,
        feedbackStore: UserFeedbackRecording? = nil,
        getReferenceImage: @escaping @MainActor () -> NSImage? = { nil },
        viewModel: PetViewModel? = nil,
        hasActiveOverlayProvider: @escaping @MainActor () -> Bool = { false }
    ) {
        self.coordinator = coordinator
        self.generationService = generationService
        self.assetStore = assetStore
        self.stateController = stateController
        self.safetyService = safetyService
        self.quotaStore = quotaStore
        self.preferencesStore = preferencesStore
        self.visualPreferenceStore = visualPreferenceStore
        self.diagnosticsStore = diagnosticsStore
        self.generationDiagnosticsRecorder = generationDiagnosticsRecorder
        self.petIdentityDescriber = petIdentityDescriber
        self.promptStrategy = promptStrategy
        self.referenceImageProvider = referenceImageProvider
        self.referenceImagePipeline = referenceImagePipeline
        self.qualityGateChecker = qualityGateChecker
        self.lifecycleManager = lifecycleManager
        self.feedbackStore = feedbackStore
        self.getReferenceImage = getReferenceImage
        self.hasActiveOverlayProvider = hasActiveOverlayProvider
        self.viewModel = viewModel

        coordinator.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleCoordinatorEvent(event)
            }
        }
    }

    public func setViewModel(_ vm: PetViewModel) {
        viewModel = vm
    }

    // MARK: - AIVisualActionMediating

    public func handleCandidates(from response: AIChatResponse, petId: String) {
        let candidates = response.visualActionCandidates
        guard !candidates.isEmpty else { return }

        let prefs = preferencesStore.loadPreferences()
        guard prefs.isEnabled else { return }

        let context = buildContext(preferences: prefs, petId: petId, petName: "")

        for candidate in candidates {
            let safetyResult = safetyService.validate(candidate: candidate)
            guard safetyResult.isAllowed else {
                diagnosticsStore?.record(AIVisualMetricEvent(
                    type: .safetyRejected,
                    actionId: candidate.id,
                    petId: petId
                ))
                onPolicyDenied?(safetyResult.userFacingText)
                continue
            }
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .candidateParsed,
                actionId: candidate.id,
                petId: petId
            ))
            _ = coordinator.processCandidate(candidate, context: context)
        }
    }

    public func requestManualGeneration(petId: String, petName: String) {
        let prefs = preferencesStore.loadPreferences()
        guard prefs.isEnabled else {
            onPolicyDenied?(userFacingText(for: .visualExpressionDisabled))
            return
        }

        let candidate = AIVisualActionCandidate(
            id: "manual-\(UUID().uuidString)",
            petId: petId,
            source: .userRequest,
            kind: .ambience,
            description: Self.manualGenerationDescription,
            renderMode: .replaceWholeImage,
            requestedDurationSeconds: prefs.durationPreset.durationSeconds,
            impact: .low
        )

        let safetyResult = safetyService.validate(candidate: candidate)
        guard safetyResult.isAllowed else {
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .safetyRejected,
                actionId: candidate.id,
                petId: petId
            ))
            onPolicyDenied?(safetyResult.userFacingText)
            return
        }

        diagnosticsStore?.record(AIVisualMetricEvent(
            type: .candidateParsed,
            actionId: candidate.id,
            petId: petId
        ))
        _ = coordinator.processCandidate(
            candidate,
            context: buildContext(preferences: prefs, petId: petId, petName: petName)
        )
    }

    public func confirmAction(requestId: String) {
        let result = coordinator.confirmAction(requestId)
        if case .failure = result {
            onGenerationFailed?("确认失败")
        }
    }

    public func rejectAction(requestId: String) {
        coordinator.rejectAction(requestId)
    }

    public func restoreVisual() {
        guard let vm = viewModel else { return }
        if let overlayId = vm.visualOverlay?.id {
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .overlayRestored,
                actionId: overlayId,
                petId: ""
            ))
        }
        if let overlay = vm.visualOverlay {
            Task {
                let asset = assetStore.loadAsset(id: overlay.assetId, petId: "")
                if let asset {
                    try? await lifecycleManager?.transition(asset: asset, to: .restored)
                }
            }
        }
        stateController.restore(viewModel: vm)
        onVisualRestored?()
    }

    public func applyAsset(_ asset: PetVisualAsset, expiresAt: Date) {
        guard let vm = viewModel else { return }
        let overlay = PetVisualOverlayState(
            id: UUID().uuidString,
            assetId: asset.id,
            imageURL: asset.localURL,
            renderMode: asset.renderMode,
            startedAt: Date(),
            expiresAt: expiresAt
        )
        stateController.apply(overlay, to: vm)
        Task {
            try? await lifecycleManager?.transition(asset: asset, to: .applied)
        }
        diagnosticsStore?.record(AIVisualMetricEvent(
            type: .overlayApplied,
            actionId: asset.id,
            petId: asset.petId
        ))
    }

    public func discardAsset(_ asset: PetVisualAsset) {
        Task {
            try? await lifecycleManager?.transition(asset: asset, to: .discardedByUser)
        }
    }

    public func retryAsset(_ asset: PetVisualAsset, petId: String, petName: String) {
        Task {
            try? await lifecycleManager?.transition(asset: asset, to: .discardedByUser)
        }
        requestManualGeneration(petId: petId, petName: petName)
    }

    public func recordFeedback(type: PreviewFeedbackType, asset: PetVisualAsset) {
        let context = FeedbackContext(
            petId: asset.petId,
            promptDigest: asset.promptDigest,
            lifecycleState: asset.lifecycleState
        )
        try? feedbackStore?.recordFeedback(
            assetId: asset.id,
            type: type,
            context: context
        )

        if let diagnosticsId = asset.generationDiagnosticsId,
           var record = try? generationDiagnosticsRecorder?.loadRecord(requestId: diagnosticsId) {
            generationDiagnosticsRecorder?.recordUserAction(&record, action: Self.feedbackToDiagnosticsAction(type))
            _ = try? generationDiagnosticsRecorder?.finalize(record)
        }
    }

    private static func feedbackToDiagnosticsAction(_ type: PreviewFeedbackType) -> DiagnosticsUserAction {
        switch type {
        case .notLikeOriginal: return .feedbackNotLikeOriginal
        case .styleWrong: return .feedbackStyleWrong
        case .colorWrong: return .feedbackColorWrong
        case .accessoryLost: return .feedbackAccessoryLost
        case .goodDirection: return .feedbackGoodDirection
        }
    }

    // MARK: - Coordinator Event Handling

    private func handleCoordinatorEvent(_ event: AIVisualCoordinatorEvent) {
        switch event {
        case .readyForGeneration(_, let candidate):
            Task {
                await performGeneration(candidate: candidate)
            }

        case .confirmationRequested(_, let request):
            onConfirmationRequested?(request)

        case .policyDenied(let actionId, let reason):
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .policyDenied,
                actionId: actionId,
                petId: "",
                denyReason: String(describing: reason)
            ))
            if reason == .quotaExceeded {
                diagnosticsStore?.record(AIVisualMetricEvent(
                    type: .quotaExceeded,
                    actionId: actionId,
                    petId: ""
                ))
            }
            let text = userFacingText(for: reason)
            onPolicyDenied?(text)

        case .confirmed(let actionId):
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .confirmationAccepted,
                actionId: actionId,
                petId: ""
            ))

        case .rejected(let actionId):
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .confirmationRejected,
                actionId: actionId,
                petId: ""
            ))
        }
    }

    // MARK: - Generation Pipeline

    private func performGeneration(candidate: AIVisualActionCandidate) async {
        let startTime = Date()
        var generationRecord = generationDiagnosticsRecorder?.beginRecord(
            requestId: candidate.id,
            petId: candidate.petId
        )
        diagnosticsStore?.record(AIVisualMetricEvent(
            type: .generationStarted,
            actionId: candidate.id,
            petId: candidate.petId,
            providerId: generationService.currentProviderId()
        ))
        do {
            try quotaStore.reserve(
                petId: candidate.petId,
                actionId: candidate.id,
                source: candidate.source,
                at: Date()
            )

            let pendingDir = try assetStore.preparePendingDirectory(
                petId: candidate.petId,
                actionId: candidate.id
            )

            let petDescriptor = await petIdentityDescriber?.descriptor(for: candidate.petId)
            let consistencyPreference = await visualPreferenceStore?.preference(for: candidate.petId) ?? .conservative
            let generationIntent = GenerationIntent.defaultIntent(
                for: candidate.source,
                preference: consistencyPreference
            )
            let identityDescription = buildPetDescriptorString(petDescriptor)

            let prompt: String
            let promptStrategyResult: PromptStrategyResult?
            if let strategy = promptStrategy, let descriptor = petDescriptor {
                let result = strategy.buildPrompt(
                    intent: generationIntent,
                    petDescriptor: descriptor,
                    preference: consistencyPreference,
                    actionKind: candidate.kind
                )
                promptStrategyResult = result
                prompt = result.finalPrompt
            } else {
                promptStrategyResult = nil
                prompt = safetyService.sanitizePrompt(
                    candidate.description,
                    petDescriptor: identityDescription
                )
            }
            if var record = generationRecord {
                generationDiagnosticsRecorder?.recordPrompt(&record, finalPrompt: prompt)
                generationRecord = record
            }

            let referenceImageURL: URL?
            let processedReference: ProcessedReference?
            if let pipeline = referenceImagePipeline {
                processedReference = try await exportAndProcessReferenceImage(petId: candidate.petId, pipeline: pipeline)
                referenceImageURL = processedReference?.providerFriendly
            } else {
                processedReference = nil
                referenceImageURL = exportReferenceImage(petId: candidate.petId)
            }
            if let referenceImageURL, var record = generationRecord,
               let info = try? generationDiagnosticsRecorder?.referenceImageInfo(
                for: referenceImageURL,
                petId: candidate.petId
               ) {
                generationDiagnosticsRecorder?.recordReferenceImage(&record, info: info)
                generationRecord = record
            }

            let request = VisualGenerationRequest(
                actionId: candidate.id,
                petId: candidate.petId,
                prompt: prompt,
                referenceImageURL: referenceImageURL,
                aspectRatio: "1:1",
                outputDirectory: pendingDir,
                outputPrefix: candidate.id,
                count: 1,
                generationIntent: generationIntent,
                consistencyPreference: consistencyPreference,
                processedReferenceURL: processedReference?.providerFriendly,
                negativeConstraints: promptStrategyResult?.negativeConstraints,
                identityDescription: identityDescription.isEmpty ? nil : identityDescription
            )
            if var record = generationRecord {
                generationDiagnosticsRecorder?.recordProviderParams(
                    &record,
                    params: ProviderParamsSnapshot(
                        providerId: generationService.currentProviderId() ?? "unknown",
                        subjectRefIncluded: referenceImageURL != nil
                    )
                )
                generationRecord = record
            }

            let result = try await generationService.generate(request)
            if var record = generationRecord,
               let info = try? generationDiagnosticsRecorder?.outputImageInfo(for: result.imageURL) {
                generationDiagnosticsRecorder?.recordOutput(&record, info: info)
                generationRecord = record
            }

            let prefs = preferencesStore.loadPreferences()
            let expiresAt = Date().addingTimeInterval(prefs.durationPreset.durationSeconds)

            // D-5.15: Quality gate check
            var gateResult: GateResult?
            if let gateChecker = qualityGateChecker,
               let refSnapshot = processedReference?.originalInfo {
                gateResult = try await gateChecker.evaluate(
                    reference: refSnapshot,
                    output: result.imageURL,
                    petDescriptor: petDescriptor ?? PetDescriptor(petId: candidate.petId),
                    preference: await visualPreferenceStore?.preference(for: candidate.petId) ?? .conservative
                )
            }

            // Determine effective action before commit
            var effectiveAction = gateResult?.autoAction ?? .applyDirectly
            if effectiveAction == .applyDirectly, candidate.renderMode == .replaceWholeImage {
                effectiveAction = .requirePreview
            }

            let initialLifecycleState: AssetLifecycleState = {
                switch effectiveAction {
                case .applyDirectly: return .applied
                case .requirePreview: return .generatedPendingPreview
                case .rejectWithMessage: return .rejectedByGate
                }
            }()

            let referencePreviewForAsset = processedReference?.transparentPNG ?? processedReference?.providerFriendly

            let asset = try assetStore.commitAsset(
                from: result.imageURL,
                petId: candidate.petId,
                actionId: candidate.id,
                providerId: result.providerId,
                kind: candidate.kind,
                renderMode: candidate.renderMode,
                promptDigest: PetVisualAssetStore.digestPrompt(prompt),
                expiresAt: expiresAt,
                lifecycleState: initialLifecycleState,
                gateResult: gateResult,
                referencePreviewURL: referencePreviewForAsset,
                diagnosticsId: candidate.id
            )

            try quotaStore.markSucceeded(
                actionId: candidate.id,
                providerId: result.providerId,
                assetId: asset.id,
                at: Date()
            )

            // D-5.16: Record gate result to diagnostics
            if let gate = gateResult, var record = generationRecord {
                generationDiagnosticsRecorder?.recordGateResult(&record, result: GenerationDiagnosticsGateResult(
                    verdict: gate.overall.rawValue,
                    reason: gate.checks.filter { !$0.passed }.map { "\($0.checkType.rawValue): \($0.detail)" }.joined(separator: "; ")
                ))
                generationRecord = record
            }

            // Determine effective action (renderMode override: replaceWholeImage never auto-applies)
            // NOTE: effectiveAction already determined above before commit

            if effectiveAction == .applyDirectly, let vm = viewModel {
                let overlay = PetVisualOverlayState(
                    id: UUID().uuidString,
                    assetId: asset.id,
                    imageURL: asset.localURL,
                    renderMode: candidate.renderMode,
                    startedAt: Date(),
                    expiresAt: expiresAt
                )
                stateController.apply(overlay, to: vm)
                diagnosticsStore?.record(AIVisualMetricEvent(
                    type: .overlayApplied,
                    actionId: candidate.id,
                    petId: candidate.petId
                ))
                if var record = generationRecord {
                    generationDiagnosticsRecorder?.recordUserAction(&record, action: .applied)
                    generationRecord = record
                }
            }

            if effectiveAction == .requirePreview {
                let previewURL = asset.referencePreviewURL ?? result.imageURL
                onPreviewRequested?(asset, previewURL)
            }

            if effectiveAction == .rejectWithMessage {
                let message = gateResult?.userFacingMessage ?? "这次结果和原形象差异较大，已为你保留原样。"
                onGateRejected?(asset, message)
            }

            let elapsed = Date().timeIntervalSince(startTime)
            if var record = generationRecord {
                record.generationDurationSeconds = elapsed
                _ = try? generationDiagnosticsRecorder?.finalize(record)
            }
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .generationSucceeded,
                actionId: candidate.id,
                petId: candidate.petId,
                providerId: result.providerId,
                durationSeconds: elapsed
            ))

            onVisualChanged?(candidate.description)

        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            let providerId = generationService.currentProviderId() ?? "unknown"
            if var record = generationRecord {
                record.generationDurationSeconds = elapsed
                record.errorMessage = error.localizedDescription
                _ = try? generationDiagnosticsRecorder?.finalize(record)
            }
            assetStore.cleanupPending(actionId: candidate.id, petId: candidate.petId)
            try? quotaStore.markFailed(
                actionId: candidate.id,
                providerId: providerId,
                errorCode: String(describing: error),
                at: Date()
            )
            diagnosticsStore?.record(AIVisualMetricEvent(
                type: .generationFailed,
                actionId: candidate.id,
                petId: candidate.petId,
                providerId: providerId,
                errorCode: String(describing: error),
                durationSeconds: elapsed
            ))
            onGenerationFailed?(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private static let manualGenerationDescription = "a gentle ambient variation"

    private func buildContext(
        preferences: AIVisualPreferences,
        petId: String,
        petName: String
    ) -> AIVisualActionContext {
        let hasActiveOverlay = hasActiveOverlayProvider()
        let visualPrefs = visualPreferenceStore?.loadPreferences()
        return coordinator.buildContext(
            isAIEnabled: true,
            isVisualExpressionEnabled: preferences.isEnabled,
            isQuietMode: false,
            isBubbleEnabled: true,
            petId: petId,
            petName: petName,
            hasActiveOverlay: hasActiveOverlay,
            preferredThemes: visualPrefs?.preferredThemes ?? [],
            dislikedContent: visualPrefs?.dislikedContent ?? [],
            activeFavoriteId: visualPrefs?.activeFavoriteId
        )
    }

    private func exportReferenceImage(petId: String) -> URL? {
        guard let image = getReferenceImage() else { return nil }
        return try? referenceImageProvider.exportReferenceImage(petId: petId, image: image)
    }

    private func exportAndProcessReferenceImage(petId: String, pipeline: ReferenceImageProcessing) async throws -> ProcessedReference? {
        guard let image = getReferenceImage() else { return nil }
        let rawURL = try referenceImageProvider.exportReferenceImage(petId: petId, image: image)
        return try await pipeline.process(petId: petId, sourceURL: rawURL)
    }

    private func buildPetDescriptorString(_ descriptor: PetDescriptor?) -> String {
        guard let descriptor else { return "" }
        var parts: [String] = []
        if let name = descriptor.nameHint { parts.append(name) }
        if let species = descriptor.speciesHint { parts.append("species: \(species)") }
        if let traits = descriptor.referenceImageTraits {
            if !traits.dominantColors.isEmpty {
                parts.append("colors: \(traits.dominantColors.joined(separator: ", "))")
            }
            if let style = traits.estimatedStyle { parts.append("style: \(style)") }
            if traits.width > 0, traits.height > 0 {
                parts.append("size: \(traits.width)x\(traits.height)")
            }
            if traits.hasAlpha { parts.append("transparent sprite") }
        }
        if let notes = descriptor.visualNotes, !notes.isEmpty {
            parts.append("notes: \(notes)")
        }
        return parts.joined(separator: "; ")
    }

    private func userFacingText(for reason: AIVisualDenyReason) -> String? {
        switch reason {
        case .aiDisabled: return "AI 功能未开启"
        case .visualExpressionDisabled: return "AI 视觉表达未开启"
        case .quietMode: return "安静模式下不会主动变化"
        case .bubbleDisabled: return "气泡未开启"
        case .quotaExceeded: return "今日的变化次数已用完"
        case .rateLimited: return "变化太频繁了，稍后再试"
        case .safetyRejected: return "这个不太适合变出来"
        case .generationInProgress: return "已有视觉变化正在生效"
        case .kindNotAllowed: return "当前阶段不支持这种类型的变化"
        }
    }
}
