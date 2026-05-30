import DesktopPet
import Foundation

// MARK: - Entry point

@MainActor
func runInteractiveValidation() {
    print("=== DesktopPetInteractiveValidation ===")
    print("")

    validateFirstLaunchGreeting()
    validateDailyFirstVisitAddsPoints()
    validatePetFeedActionPlayedAddPoints()
    validateRelationshipLevelUp()
    validateLongAbsenceNoPenalty()
    validateQuietForOneHourSuppressesAmbientBubble()
    validateDisabledBubblesHideInteractionBubble()
    validateMicroDialogOptionExecution()
    validateSwitchPetKeepsRelationshipIndependent()

    validateAIVisualEndToEndFlow()
    validateAIVisualQuotaEnforcementFlow()
    validateAIVisualSafetyRejectionFlow()
    validateAIVisualStateLifecycleFlow()

    print("")
    print("DesktopPetInteractiveValidation passed")
}

// MARK: - Helpers

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("InteractiveValidation failed: \(message)\n", stderr)
        Foundation.exit(1)
    }
}

private func fail(_ message: String) -> Never {
    fputs("InteractiveValidation failed: \(message)\n", stderr)
    Foundation.exit(1)
}

private func makeDefaultRuntimeState() -> PetRuntimeState {
    PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.2,
        energy: 0.8,
        lastInteractionAt: Date(),
        isDragging: false,
        scale: 1.0
    )
}

private func makeRuleContext(
    runtimeState: PetRuntimeState = makeDefaultRuntimeState()
) -> RelationshipRuleContext {
    RelationshipRuleContext(runtimeState: runtimeState)
}

// MARK: - Test doubles

private final class InMemoryRelationshipStore: RelationshipStoring, @unchecked Sendable {
    private var states: [String: RelationshipState] = [:]

    func loadState(petId: String) throws -> RelationshipState {
        states[petId] ?? RelationshipState()
    }

    func saveState(_ state: RelationshipState, petId: String) throws {
        states[petId] = state
    }

    func resetState(petId: String) throws {
        states.removeValue(forKey: petId)
    }
}

private final class InMemoryCompanionPreferencesStore: CompanionPreferencesStoring, @unchecked Sendable {
    private var preferences = CompanionPreferences()

    func loadPreferences() -> CompanionPreferences {
        preferences
    }

    func savePreferences(_ preferences: CompanionPreferences) {
        self.preferences = preferences
    }
}

// MARK: - 1. 验证首次启动问候

@MainActor
private func validateFirstLaunchGreeting() {
    print("1. 首次启动问候...")

    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: .current)
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()
    let router = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()

    let result = router.handle(CompanionEvent.appBecameVisible(now), runtimeState: runtimeState)

    expect(result.relationshipUpdate != nil,
           "首次启动应产生关系更新")
    expect(result.relationshipUpdate?.pointsAdded == 3,
           "每日首次出现应加 3 分")

    let ctx = router.context(runtimeState: runtimeState)
    expect(ctx.relationship.intimacyPoints == 3,
           "context 中应反映 3 点亲密度")

    print("   ✅ 首次启动产生问候和 +3 分")
}

// MARK: - 2. 验证每日首次出现加分

@MainActor
private func validateDailyFirstVisitAddsPoints() {
    print("2. 每日首次出现加分...")

    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: .current)
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()
    let router = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()

    // First daily visit
    let result1 = router.handle(CompanionEvent.dailyFirstVisit(now), runtimeState: runtimeState)
    expect(result1.relationshipUpdate?.pointsAdded == 3,
           "每日首次出现应加 3 分")

    // Second daily visit same day - should not add
    let result2 = router.handle(CompanionEvent.dailyFirstVisit(now), runtimeState: runtimeState)
    expect(result2.relationshipUpdate == nil || result2.relationshipUpdate?.pointsAdded == 0,
           "同日第二次每日首次出现不应再加 3 分")

    print("   ✅ 每天只加一次 +3 分")
}

// MARK: - 3. 验证摸摸 / 喂食 / 动作播放加分

@MainActor
private func validatePetFeedActionPlayedAddPoints() {
    print("3. 摸摸 / 喂食 / 动作播放加分...")

    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: .current)
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()
    let router = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()

    // Pet: +2
    let petResult = router.handle(
        CompanionEvent.directInteraction(.pet, now),
        runtimeState: runtimeState
    )
    expect(petResult.relationshipUpdate?.pointsAdded == 2,
           "摸摸应加 2 分")

    // Feed: +2 (hunger low)
    let feedResult = router.handle(
        CompanionEvent.directInteraction(.feed, now),
        runtimeState: runtimeState
    )
    expect(feedResult.relationshipUpdate?.pointsAdded == 2,
           "喂食应加 2 分（低饥饿）")

    // Feed when hungry: +3
    let hungryState = PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.8,
        energy: 0.8,
        lastInteractionAt: now,
        isDragging: false,
        scale: 1.0
    )
    let later = now.addingTimeInterval(700)
    let clockLater = FixedCompanionClock(now: later, calendar: .current)
    let store2 = InMemoryRelationshipStore()
    let prefsStore2 = InMemoryCompanionPreferencesStore()
    let router2 = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store2,
        preferencesStore: prefsStore2,
        clock: clockLater
    )
    let hungryFeedResult = router2.handle(
        CompanionEvent.directInteraction(.feed, later),
        runtimeState: hungryState
    )
    expect(hungryFeedResult.relationshipUpdate?.pointsAdded == 3,
           "高饥饿喂食应加 3 分（2+1 额外）")

    // Action played: +1
    let actionResult = router.handle(
        CompanionEvent.actionPlayed(ActionId(rawValue: "test_action")!, now),
        runtimeState: runtimeState
    )
    expect(actionResult.relationshipUpdate?.pointsAdded == 1,
           "动作播放应加 1 分")

    // Click: +1
    let clickResult = router.handle(
        CompanionEvent.directInteraction(.click, now),
        runtimeState: runtimeState
    )
    expect(clickResult.relationshipUpdate?.pointsAdded == 1,
           "点击应加 1 分")

    print("   ✅ 摸摸 +2、喂食 +2/3、动作 +1、点击 +1")
}

// MARK: - 4. 验证关系升级事件

@MainActor
private func validateRelationshipLevelUp() {
    print("4. 关系升级事件...")

    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: .current)
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()
    let router = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()

    // Start with daily first visit: +3 (total: 3)
    _ = router.handle(CompanionEvent.dailyFirstVisit(now), runtimeState: runtimeState)

    // Accumulate points to reach Lv.2 (100 points)
    var totalPoints = 3
    var currentDate = now
    while totalPoints < 100 {
        currentDate = currentDate.addingTimeInterval(700)
        let result = router.handle(
            CompanionEvent.directInteraction(.pet, currentDate),
            runtimeState: runtimeState
        )
        if let added = result.relationshipUpdate?.pointsAdded, added > 0 {
            totalPoints += added
        }
    }

    let ctx = router.context(runtimeState: runtimeState)
    expect(ctx.relationship.currentLevel >= .familiar,
           "累计 100+ 分应至少到达 Lv.2 熟悉，当前: \(ctx.relationship.currentLevel.displayName)")
    expect(ctx.relationship.intimacyPoints >= 100,
           "亲密度应 >= 100，当前: \(ctx.relationship.intimacyPoints)")

    print("   ✅ 累计亲密度触发关系升级，等级: \(ctx.relationship.currentLevel.displayName)")
}

// MARK: - 5. 验证久别重逢不扣分

@MainActor
private func validateLongAbsenceNoPenalty() {
    print("5. 久别重逢不扣分...")

    let calendar = Calendar.current
    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: calendar)
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()
    let router = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()

    // Give initial points
    _ = router.handle(CompanionEvent.dailyFirstVisit(now), runtimeState: runtimeState)
    _ = router.handle(CompanionEvent.directInteraction(.pet, now), runtimeState: runtimeState)

    let ctx1 = router.context(runtimeState: runtimeState)
    let pointsBefore = ctx1.relationship.intimacyPoints
    expect(pointsBefore > 0, "初始应有亲密度")

    // Simulate long absence (5 days) - reuse the same store
    let fiveDaysLater = calendar.date(byAdding: .day, value: 5, to: now)!
    let clockLater = FixedCompanionClock(now: fiveDaysLater, calendar: calendar)

    let routerLater = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clockLater
    )
    _ = routerLater.handle(CompanionEvent.appBecameVisible(fiveDaysLater), runtimeState: runtimeState)

    let ctx2 = routerLater.context(runtimeState: runtimeState)
    let pointsAfter = ctx2.relationship.intimacyPoints

    expect(pointsAfter >= pointsBefore,
           "久别重逢不应扣分，之前: \(pointsBefore)，之后: \(pointsAfter)")
    expect(ctx2.relationship.intimacyPoints >= 0,
           "亲密度不应为负数")

    print("   ✅ 久别重逢不扣分，关系等级不变")
}

// MARK: - 6. 验证 Quiet for 1 hour 抑制自主气泡

@MainActor
private func validateQuietForOneHourSuppressesAmbientBubble() {
    print("6. Quiet for 1 hour 抑制自主气泡...")

    let now = Date()
    let quietUntil = now.addingTimeInterval(3600)

    let profile = BubbleProfile(
        phrases: [:],
        minimumIntervalSeconds: 30,
        displayDurationSeconds: 3
    )
    let catalog = BubblePhraseCatalogBuilder().build(from: nil)
    let contextualProvider = ContextualBubblePhraseProvider(
        catalog: catalog,
        randomProvider: { range in range.lowerBound }
    )
    let engine = BubbleEngine(
        profile: profile,
        isEnabled: true,
        frequency: .normal,
        phraseProvider: DefaultBubblePhraseProvider(profile: profile),
        contextualPhraseProvider: contextualProvider,
        quietModePolicy: QuietModePolicy()
    )

    let runtimeState = PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.2,
        energy: 0.8,
        lastInteractionAt: now.addingTimeInterval(-200),
        isDragging: false,
        scale: 1.0
    )

    // Normal context: should produce idle bubble
    let normalPreferences = CompanionPreferences()
    let normalCtx = CompanionContext(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        runtimeState: runtimeState,
        relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: normalPreferences,
        timeSlots: [.morning]
    )
    let normalBubble = engine.tick(context: normalCtx, at: now)
    expect(normalBubble != nil,
           "正常模式下 idle 气泡应出现")

    // Quiet context: should not produce ambient bubble
    let quietPreferences = CompanionPreferences(quietUntil: quietUntil)
    let quietCtx = CompanionContext(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        runtimeState: runtimeState,
        relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: quietPreferences,
        timeSlots: [.morning]
    )
    let quietBubble = engine.tick(context: quietCtx, at: now)
    expect(quietBubble == nil,
           "安静模式下不应出现自主 idle 气泡")

    print("   ✅ Quiet 模式抑制自主气泡，Normal 模式正常显示")
}

// MARK: - 7. 验证关闭气泡后不展示交互气泡

@MainActor
private func validateDisabledBubblesHideInteractionBubble() {
    print("7. 关闭气泡后不展示交互气泡...")

    let now = Date()
    let profile = BubbleProfile(
        phrases: [:],
        minimumIntervalSeconds: 30,
        displayDurationSeconds: 3
    )
    let catalog = BubblePhraseCatalogBuilder().build(from: nil)
    let contextualProvider = ContextualBubblePhraseProvider(
        catalog: catalog,
        randomProvider: { range in range.lowerBound }
    )
    let engine = BubbleEngine(
        profile: profile,
        isEnabled: false,
        frequency: .normal,
        phraseProvider: DefaultBubblePhraseProvider(profile: profile),
        contextualPhraseProvider: contextualProvider
    )

    let runtimeState = makeDefaultRuntimeState()
    let ctx = CompanionContext(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        runtimeState: runtimeState,
        relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: CompanionPreferences(),
        timeSlots: [.morning]
    )

    let clickBubble = engine.handle(trigger: BubbleTrigger.clicked, context: ctx, at: now)
    expect(clickBubble == nil,
           "关闭气泡后点击不应展示交互气泡")

    let idleBubble = engine.tick(context: ctx, at: now)
    expect(idleBubble == nil,
           "关闭气泡后不应展示自主气泡")

    print("   ✅ 关闭气泡后交互和自主气泡均不展示")
}

// MARK: - 8. 验证微对话选项执行

@MainActor
private func validateMicroDialogOptionExecution() {
    print("8. 微对话选项执行...")

    let now = Date()
    let service = MicroDialogService()
    let catalog = BubblePhraseCatalogBuilder.defaultCatalog()

    // Find a phrase that can start a micro dialog
    let hungryPhrases = catalog.phrases(for: .hungry)
    let dialogPhrase = hungryPhrases.first { $0.canStartMicroDialog }
    expect(dialogPhrase != nil,
           "默认文案池应有可触发微对话的饥饿短语")

    let runtimeState = PetRuntimeState(
        currentState: .idle,
        mood: 0.8,
        hunger: 0.8,
        energy: 0.8,
        lastInteractionAt: now,
        isDragging: false,
        scale: 1.0
    )
    let ctx = CompanionContext(
        petId: "pet-a",
        petDisplayName: "Test Pet",
        runtimeState: runtimeState,
        relationship: RelationshipSnapshot(intimacyPoints: 0, currentLevel: .acquaintance),
        preferences: CompanionPreferences(),
        timeSlots: [.morning]
    )

    let dialog = service.dialog(for: dialogPhrase!, context: ctx, now: now)
    expect(dialog != nil,
           "饥饿短语应生成微对话")
    expect(dialog!.options.count >= 2,
           "微对话应至少有 2 个选项")

    // Verify feed option
    let feedOption = dialog!.options.first { $0.command == .feed }
    expect(feedOption != nil,
           "饥饿微对话应包含喂食选项")

    // Execute feed command
    let feedCommand = service.command(for: feedOption!.id, now: now)
    expect(feedCommand == .feed,
           "选择喂食应返回 feed 命令")

    // Verify dismiss option
    let dismissOption = dialog!.options.first {
        if case .dismiss = $0.command { return true }
        return false
    }
    expect(dismissOption != nil,
           "饥饿微对话应包含 dismiss 选项")

    let dismissCommand = service.command(for: dismissOption!.id, now: now)
    if case .dismiss = dismissCommand {
        // OK
    } else {
        fail("选择 dismiss 应返回 dismiss 命令")
    }

    // Verify expired dialog
    let expiredDate = now.addingTimeInterval(60)
    let expiredCommand = service.command(for: feedOption!.id, now: expiredDate)
    expect(expiredCommand == nil,
           "过期微对话选项不应执行")

    // Verify microDialogCompleted event increases points
    let ruleContext = makeRuleContext(runtimeState: runtimeState)
    let rule = RelationshipRule.rule(for: CompanionEvent.microDialogCompleted(MicroDialogOptionId(rawValue: "opt_1"), now))
    expect(rule != nil,
           "microDialogCompleted 应有对应规则")

    let service2 = RelationshipService(store: InMemoryRelationshipStore())
    let update = try! service2.handle(
        event: CompanionEvent.microDialogCompleted(MicroDialogOptionId(rawValue: "opt_1"), now),
        petId: "pet-a",
        context: ruleContext
    )
    expect(update.pointsAdded == 1,
           "微对话完成应加 1 分")

    print("   ✅ 微对话选项可执行，feed 返回 feed 命令，dismiss 不负反馈")
}

// MARK: - 9. 验证切换宠物关系独立

@MainActor
private func validateSwitchPetKeepsRelationshipIndependent() {
    print("9. 切换宠物关系独立...")

    let now = Date()
    let clock = FixedCompanionClock(now: now, calendar: .current)

    // Share a single store so both pets use the same persistence
    let store = InMemoryRelationshipStore()
    let prefsStore = InMemoryCompanionPreferencesStore()

    // Pet A: add points
    let routerA = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Pet A",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let runtimeState = makeDefaultRuntimeState()
    _ = routerA.handle(CompanionEvent.dailyFirstVisit(now), runtimeState: runtimeState)
    _ = routerA.handle(CompanionEvent.directInteraction(.pet, now), runtimeState: runtimeState)

    let ctxA = routerA.context(runtimeState: runtimeState)
    let pointsA = ctxA.relationship.intimacyPoints
    expect(pointsA > 0,
           "Pet A 应有亲密度")

    // Pet B: should start from 0
    let routerB = CompanionEventRouter(
        petId: "pet-b",
        petDisplayName: "Pet B",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    let ctxB = routerB.context(runtimeState: runtimeState)
    expect(ctxB.relationship.intimacyPoints == 0,
           "Pet B 应从 0 开始")

    expect(ctxA.relationship.intimacyPoints == pointsA,
           "Pet B 的加入不影响 Pet A 的亲密度")

    // Switch back to Pet A - should still have same points
    routerA.switchPet(id: "pet-a", displayName: "Pet A")
    let ctxA2 = routerA.context(runtimeState: runtimeState)
    expect(ctxA2.relationship.intimacyPoints == pointsA,
           "切换回 Pet A 后亲密度不变")

    // Reset Pet A should not affect Pet B
    let routerC = CompanionEventRouter(
        petId: "pet-a",
        petDisplayName: "Pet A",
        relationshipStore: store,
        preferencesStore: prefsStore,
        clock: clock
    )
    _ = routerC.resetRelationship(runtimeState: runtimeState)
    let ctxC = routerC.context(runtimeState: runtimeState)
    expect(ctxC.relationship.intimacyPoints == 0,
           "Pet A 重置后应为 0 分")

    let ctxB2 = routerB.context(runtimeState: runtimeState)
    expect(ctxB2.relationship.intimacyPoints == 0,
           "Pet B 不受 Pet A 重置影响")

    print("   ✅ 切换宠物关系独立，重置互不影响")
}

// MARK: - 10. 验证 AI 视觉变化端到端流程

@MainActor
private func validateAIVisualEndToEndFlow() {
    print("10. AI 视觉变化端到端流程...")

    let parser = AIVisualActionParser()
    let policy = AIVisualActionPolicy()
    let safetyService = AIVisualSafetyService()
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("visual-e2e-\(UUID().uuidString)")
    let assetStore = PetVisualAssetStore(baseDirectory: tempDir)
    let stateController = PetVisualStateController()

    let json = """
    {"kind":"pose","description":"戴着小帽子跳舞","renderMode":"replaceWholeImage","durationSeconds":60,"impact":"low"}
    """
    let response = "小猫想表演一下 [VISUAL_ACTION]\(json)[/VISUAL_ACTION]"

    let parseResult = parser.parse(from: response, petId: "pet-a", source: .chat)
    expect(parseResult.candidates.count == 1,
           "端到端：应解析出 1 个候选")
    let candidate = parseResult.candidates.first!

    let context = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: true,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet-a", petName: "小猫",
        hasPreviousVisualAction: true
    )
    let decision = policy.evaluate(candidate, context: context)
    if case .allow = decision {
        // expected
    } else {
        fail("端到端：策略应允许该候选，得到 \(decision)")
    }

    let safetyResult = safetyService.validate(candidate: candidate)
    expect(safetyResult.isAllowed,
           "端到端：安全检查应通过")

    let imageDir = tempDir.appendingPathComponent("pending")
    try! FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
    let imageFile = imageDir.appendingPathComponent("e2e.png")
    try! Data(repeating: 0x89, count: 16).write(to: imageFile)

    let asset = try! assetStore.commitAsset(
        from: imageFile, petId: "pet-a", actionId: candidate.id,
        providerId: "mock", kind: .pose, renderMode: .replaceWholeImage,
        promptDigest: "test", expiresAt: Date().addingTimeInterval(300)
    )

    let viewModel = PetViewModel()
    let overlay = PetVisualOverlayState(
        id: asset.id, assetId: asset.id,
        imageURL: asset.localURL, renderMode: .replaceWholeImage,
        expiresAt: Date().addingTimeInterval(300)
    )
    stateController.apply(overlay, to: viewModel)
    expect(viewModel.visualOverlay != nil,
           "端到端：应显示视觉覆盖")

    stateController.restore(viewModel: viewModel)
    expect(viewModel.visualOverlay == nil,
           "端到端：恢复后应清除覆盖")

    try? FileManager.default.removeItem(at: tempDir)
    print("   ✅ AI 视觉变化端到端流程通过（解析→策略→安全→资产→状态）")
}

// MARK: - 11. 验证 AI 视觉配额执行流程

@MainActor
private func validateAIVisualQuotaEnforcementFlow() {
    print("11. AI 视觉配额执行流程...")

    let suiteName = "com.desktoppet.test.interactive.quota.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let config = AIVisualQuotaConfig(dailyAutonomousLimit: 1, dailyUserRequestLimit: 2, dailyTotalLimit: 3, monthlyTotalLimit: 80)
    let now = Date()
    let store = AIVisualQuotaStore(config: config, userDefaults: defaults, now: { now })

    expect(store.canReserve(petId: "pet-a", source: .chat, at: now) == .allowed,
           "首次自主应允许")
    try! store.reserve(petId: "pet-a", actionId: "a1", source: .chat, at: now)

    expect(store.canReserve(petId: "pet-a", source: .chat, at: now) == .dailyAutonomousExceeded,
           "第二次自主应超限")

    expect(store.canReserve(petId: "pet-a", source: .userRequest, at: now) == .allowed,
           "用户请求仍应允许")
    try! store.reserve(petId: "pet-a", actionId: "u1", source: .userRequest, at: now)
    try! store.reserve(petId: "pet-a", actionId: "u2", source: .userRequest, at: now)

    expect(store.canReserve(petId: "pet-a", source: .userRequest, at: now) == .dailyTotalExceeded,
           "总限额应生效")

    let usage = store.loadUsage(petId: "pet-a", date: now)
    expect(usage.dailyTotalCount == 3,
           "总使用次数应为 3")

    defaults.removePersistentDomain(forName: suiteName)
    print("   ✅ 配额执行流程通过（自主限制→用户请求限制→总限额）")
}

// MARK: - 12. 验证 AI 视觉安全拒绝流程

@MainActor
private func validateAIVisualSafetyRejectionFlow() {
    print("12. AI 视觉安全拒绝流程...")

    let policy = AIVisualActionPolicy()
    let safetyService = AIVisualSafetyService()

    let unsafeCandidate = AIVisualActionCandidate(
        id: "unsafe1", petId: "pet-a", source: .chat, kind: .expression,
        description: "血腥的战斗场面", renderMode: .replaceWholeImage,
        requestedDurationSeconds: 60, impact: .low
    )

    let safetyResult = safetyService.validate(candidate: unsafeCandidate)
    expect(!safetyResult.isAllowed,
           "不安全内容应被拒绝")
    expect(safetyResult.rejectionReason == .violenceOrGore,
           "应识别为暴力内容")

    let context = AIVisualActionContext(
        isAIEnabled: true, isVisualExpressionEnabled: true,
        isQuietMode: false, isBubbleEnabled: true,
        petId: "pet-a", petName: "小猫",
        hasPreviousVisualAction: true
    )

    let policyResult = policy.evaluate(unsafeCandidate, context: context)
    if case .allow = policyResult {
        // Policy allows - safety layer handles rejection separately
    } else {
        fail("策略层不负责安全检查，应由安全层处理")
    }

    let sanitized = safetyService.sanitizePrompt("开心地变成猫", petDescriptor: "一只小猫")
    expect(!sanitized.isEmpty,
           "安全提示清理应返回非空结果")

    print("   ✅ 安全拒绝流程通过（检测暴力→拒绝→策略评估）")
}

// MARK: - 13. 验证 AI 视觉状态生命周期

@MainActor
private func validateAIVisualStateLifecycleFlow() {
    print("13. AI 视觉状态生命周期...")

    let stateController = PetVisualStateController()
    let viewModel = PetViewModel()
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("visual-lifecycle-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let imageURL = tempDir.appendingPathComponent("lifecycle.png")
    try! Data(repeating: 0x89, count: 8).write(to: imageURL)

    expect(viewModel.visualOverlay == nil,
           "初始状态应为空")

    let overlay1 = PetVisualOverlayState(
        id: "o1", assetId: "a1",
        imageURL: imageURL, renderMode: .replaceWholeImage,
        expiresAt: Date().addingTimeInterval(300)
    )
    stateController.apply(overlay1, to: viewModel)
    expect(viewModel.visualOverlay?.id == "o1",
           "应用后应显示第一个覆盖")

    let overlay2 = PetVisualOverlayState(
        id: "o2", assetId: "a2",
        imageURL: imageURL, renderMode: .overlayImage,
        expiresAt: Date().addingTimeInterval(300)
    )
    stateController.apply(overlay2, to: viewModel)
    expect(viewModel.visualOverlay?.id == "o2",
           "应用新覆盖应替换旧覆盖")

    stateController.clearAll(viewModel: viewModel)
    expect(viewModel.visualOverlay == nil,
           "clearAll 应清除所有覆盖")

    try? FileManager.default.removeItem(at: tempDir)
    print("   ✅ 视觉状态生命周期通过（应用→替换→清除）")
}

Task { @MainActor in
    runInteractiveValidation()
    Foundation.exit(0)
}

RunLoop.main.run()
