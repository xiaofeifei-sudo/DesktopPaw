import Foundation
import DesktopPet

@MainActor
func runMemoryModule2Tests() {
    let tests = MemoryModule2Tests()
    tests.emotionalMoodValues()
    tests.moodValence()
    tests.moodTrendValues()
    tests.relationshipPhaseValues()
    tests.interactionStyleValues()
    tests.emotionalModelDefault()
    tests.emotionalModelCodable()
    tests.dailyEmotionCreation()
    tests.emotionalPatternCreation()
    tests.storeLoadDefault()
    tests.storeSaveAndLoad()
    tests.storeCacheHit()
    tests.parseEmotionSignalValid()
    tests.parseEmotionSignalInvalidMood()
    tests.parseEmotionSignalNoTag()
    tests.parseEmotionSignalConfidenceClamped()
    tests.updateAfterSessionWithSignals()
    tests.updateAfterSessionNoSignals()
    tests.updateAfterSessionTrimsRecentEmotions()
    tests.updateAfterSessionSameDayReplaces()
    tests.updateAfterSessionIncrementsTotalSessions()
    tests.moodTrendDeclining()
    tests.moodTrendImproving()
    tests.moodTrendStable()
    tests.moodTrendUnknownWithFewEmotions()
    tests.relationshipPhaseStrangerToFamiliar()
    tests.relationshipPhaseFamiliarToClose()
    tests.relationshipPhaseCloseToBonded()
    tests.relationshipPhaseNoRegress()
    tests.shouldRecalculatePatterns()
    tests.shouldNotRecalculatePatterns()
    tests.detectCrisisSignalPositive()
    tests.detectCrisisSignalNegative()
}

@MainActor
private struct MemoryModule2Tests {
    private let testPetId = "mod2-test-\(UUID().uuidString.prefix(8))"

    private func makeStore() -> EmotionalModelStore {
        EmotionalModelStore()
    }

    private func cleanup(petId: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = appSupport
            .appendingPathComponent("DesktopPet")
            .appendingPathComponent(petId)
            .appendingPathComponent("emotional-model.json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 2.1 Data Model

    func emotionalMoodValues() {
        let allCases = EmotionalMood.allCases
        expect(allCases.contains(.happy), "should contain happy")
        expect(allCases.contains(.relaxed), "should contain relaxed")
        expect(allCases.contains(.neutral), "should contain neutral")
        expect(allCases.contains(.tired), "should contain tired")
        expect(allCases.contains(.stressed), "should contain stressed")
        expect(allCases.contains(.sad), "should contain sad")
        expect(allCases.contains(.anxious), "should contain anxious")
        expect(allCases.contains(.excited), "should contain excited")
        expect(allCases.count == 8, "should have 8 moods, got \(allCases.count)")
    }

    func moodValence() {
        expect(EmotionalMood.excited.valence > EmotionalMood.happy.valence, "excited > happy")
        expect(EmotionalMood.happy.valence > EmotionalMood.relaxed.valence, "happy > relaxed")
        expect(EmotionalMood.relaxed.valence > EmotionalMood.neutral.valence, "relaxed > neutral")
        expect(EmotionalMood.neutral.valence > EmotionalMood.tired.valence, "neutral > tired")
        expect(EmotionalMood.tired.valence > EmotionalMood.stressed.valence, "tired > stressed")
        expect(EmotionalMood.stressed.valence > EmotionalMood.anxious.valence, "stressed > anxious")
        expect(EmotionalMood.anxious.valence > EmotionalMood.sad.valence, "anxious > sad")
    }

    func moodTrendValues() {
        let improving = MoodTrend(rawValue: "improving")
        let stable = MoodTrend(rawValue: "stable")
        let declining = MoodTrend(rawValue: "declining")
        let unknown = MoodTrend(rawValue: "unknown")
        expect(improving == .improving, "improving should parse")
        expect(stable == .stable, "stable should parse")
        expect(declining == .declining, "declining should parse")
        expect(unknown == .unknown, "unknown should parse")
    }

    func relationshipPhaseValues() {
        let allCases = RelationshipPhase.allCases
        expect(allCases == [.stranger, .familiar, .close, .bonded], "phases should be in order")
    }

    func interactionStyleValues() {
        expect(InteractionStyle(rawValue: "casual") == .casual, "casual should parse")
        expect(InteractionStyle(rawValue: "formal") == .formal, "formal should parse")
        expect(InteractionStyle(rawValue: "playful") == .playful, "playful should parse")
    }

    func emotionalModelDefault() {
        let model = AIEmotionalModel()
        expect(model.currentMood == .neutral, "default mood should be neutral")
        expect(model.moodTrend == .unknown, "default trend should be unknown")
        expect(model.recentEmotions.isEmpty, "default recentEmotions should be empty")
        expect(model.emotionalPatterns.isEmpty, "default patterns should be empty")
        expect(model.relationshipPhase == .stranger, "default phase should be stranger")
        expect(model.interactionStyle == .casual, "default style should be casual")
        expect(model.topicsOfInterest.isEmpty, "default topics should be empty")
        expect(model.totalSessions == 0, "default sessions should be 0")
    }

    func emotionalModelCodable() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let emotionDate = Date(timeIntervalSince1970: 1699990000)
        let model = AIEmotionalModel(
            currentMood: .happy,
            moodTrend: .improving,
            recentEmotions: [DailyEmotion(date: emotionDate, dominant: .happy, confidence: 0.8)],
            emotionalPatterns: [EmotionalPattern(pattern: "周末更活跃", confidence: 0.7, evidence: 5)],
            relationshipPhase: .familiar,
            interactionStyle: .playful,
            topicsOfInterest: ["编程", "音乐"],
            totalSessions: 15,
            lastUpdatedAt: fixedDate
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(model)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(AIEmotionalModel.self, from: data)

        expect(decoded == model, "round-trip should be equal")
        expect(decoded.currentMood == .happy, "mood should decode")
        expect(decoded.totalSessions == 15, "sessions should decode")
        expect(decoded.topicsOfInterest == ["编程", "音乐"], "topics should decode")
    }

    func dailyEmotionCreation() {
        let date = Date()
        let emotion = DailyEmotion(date: date, dominant: .happy, confidence: 0.85)
        expect(emotion.date == date, "date should match")
        expect(emotion.dominant == .happy, "mood should be happy")
        expect(emotion.confidence == 0.85, "confidence should be 0.85")
    }

    func emotionalPatternCreation() {
        var pattern = EmotionalPattern(pattern: "工作日晚上偏疲惫", confidence: 0.75, evidence: 8)
        expect(pattern.pattern == "工作日晚上偏疲惫", "pattern should match")
        expect(pattern.confidence == 0.75, "confidence should be 0.75")
        expect(pattern.evidence == 8, "evidence should be 8")

        pattern.confidence = 0.9
        pattern.evidence = 10
        expect(pattern.confidence == 0.9, "confidence should update")
        expect(pattern.evidence == 10, "evidence should update")
    }

    // MARK: - 2.2 Storage

    func storeLoadDefault() {
        let store = makeStore()
        defer { cleanup(petId: testPetId) }

        let model = try! store.loadModel(petId: testPetId)
        expect(model.currentMood == .neutral, "default mood should be neutral")
        expect(model.totalSessions == 0, "default sessions should be 0")
        expect(model.relationshipPhase == .stranger, "default phase should be stranger")
    }

    func storeSaveAndLoad() {
        let store = makeStore()
        defer { cleanup(petId: testPetId) }

        let saved = AIEmotionalModel(
            currentMood: .happy,
            moodTrend: .improving,
            relationshipPhase: .familiar,
            totalSessions: 12
        )
        try! store.saveModel(saved, petId: testPetId)

        // Clear cache to force disk read
        let freshStore = EmotionalModelStore()
        let loaded = try! freshStore.loadModel(petId: testPetId)

        expect(loaded.currentMood == .happy, "loaded mood should be happy")
        expect(loaded.moodTrend == .improving, "loaded trend should be improving")
        expect(loaded.relationshipPhase == .familiar, "loaded phase should be familiar")
        expect(loaded.totalSessions == 12, "loaded sessions should be 12")
    }

    func storeCacheHit() {
        let store = makeStore()
        defer { cleanup(petId: testPetId) }

        let saved = AIEmotionalModel(currentMood: .excited, totalSessions: 5)
        try! store.saveModel(saved, petId: testPetId)

        let loaded = try! store.loadModel(petId: testPetId)
        expect(loaded.currentMood == .excited, "cache hit should return excited")
    }

    // MARK: - 2.3 Tracking Service

    func parseEmotionSignalValid() {
        let service = EmotionalTrackingService()
        let signal = service.parseEmotionSignal(from: "今天真开心[EMOTION:happy:0.8]")
        expect(signal != nil, "should parse valid signal")
        expect(signal?.mood == .happy, "mood should be happy")
        expect(signal?.confidence == 0.8, "confidence should be 0.8")
    }

    func parseEmotionSignalInvalidMood() {
        let service = EmotionalTrackingService()
        let signal = service.parseEmotionSignal(from: "[EMOTION:invalid:0.5]")
        expect(signal == nil, "should return nil for invalid mood")
    }

    func parseEmotionSignalNoTag() {
        let service = EmotionalTrackingService()
        let signal = service.parseEmotionSignal(from: "今天天气不错")
        expect(signal == nil, "should return nil when no tag")
    }

    func parseEmotionSignalConfidenceClamped() {
        let service = EmotionalTrackingService()
        let signal = service.parseEmotionSignal(from: "[EMOTION:sad:1.5]")
        expect(signal != nil, "should parse with clamped confidence")
        expect(signal!.confidence == 1.0, "confidence should be clamped to 1.0")
    }

    func updateAfterSessionWithSignals() {
        let service = EmotionalTrackingService()
        let model = AIEmotionalModel()
        let signal = EmotionSignal(mood: .happy, confidence: 0.9)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.currentMood == .happy, "mood should be happy")
        expect(updated.totalSessions == 1, "sessions should be 1")
        expect(updated.recentEmotions.count == 1, "should have 1 daily emotion")
        expect(updated.recentEmotions.first?.dominant == .happy, "daily emotion should be happy")
    }

    func updateAfterSessionNoSignals() {
        let service = EmotionalTrackingService()
        let model = AIEmotionalModel(currentMood: .relaxed)
        let updated = service.updateAfterSession(signals: [], model: model)

        expect(updated.currentMood == .relaxed, "mood should stay relaxed")
        expect(updated.totalSessions == 1, "sessions should increment")
        expect(updated.recentEmotions.isEmpty, "no daily emotion added without signals")
    }

    func updateAfterSessionTrimsRecentEmotions() {
        let service = EmotionalTrackingService()
        let now = Date()
        var oldEmotions: [DailyEmotion] = []
        for i in 0..<40 {
            let date = Calendar.current.date(byAdding: .day, value: -(40 - i), to: now)!
            oldEmotions.append(DailyEmotion(date: Calendar.current.startOfDay(for: date), dominant: .neutral, confidence: 0.5))
        }
        let model = AIEmotionalModel(recentEmotions: oldEmotions)
        let signal = EmotionSignal(mood: .happy, confidence: 0.8)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.recentEmotions.count <= 31, "should trim to ~30 days + today, got \(updated.recentEmotions.count)")
    }

    func updateAfterSessionSameDayReplaces() {
        let service = EmotionalTrackingService()
        let today = Calendar.current.startOfDay(for: Date())
        let model = AIEmotionalModel(
            recentEmotions: [DailyEmotion(date: today, dominant: .neutral, confidence: 0.5)]
        )
        let signal = EmotionSignal(mood: .happy, confidence: 0.9)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.recentEmotions.count == 1, "should have 1 daily emotion for today")
        expect(updated.recentEmotions.first?.dominant == .happy, "should replace with higher confidence")
        expect(updated.recentEmotions.first?.confidence == 0.9, "confidence should be 0.9")
    }

    func updateAfterSessionIncrementsTotalSessions() {
        let service = EmotionalTrackingService()
        let model = AIEmotionalModel(totalSessions: 9)
        let updated = service.updateAfterSession(signals: [], model: model)
        expect(updated.totalSessions == 10, "should be 10, got \(updated.totalSessions)")
    }

    // MARK: - Mood Trend

    func moodTrendDeclining() {
        let service = EmotionalTrackingService()
        let now = Date()
        var emotions: [DailyEmotion] = []
        for i in 0..<6 {
            let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: now)!
            let mood: EmotionalMood = i < 3 ? .happy : .sad
            emotions.append(DailyEmotion(date: Calendar.current.startOfDay(for: date), dominant: mood, confidence: 0.8))
        }
        let model = AIEmotionalModel(recentEmotions: emotions, totalSessions: 10)
        let signal = EmotionSignal(mood: .sad, confidence: 0.9)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.moodTrend == .declining, "mood trend should be declining, got \(updated.moodTrend)")
    }

    func moodTrendImproving() {
        let service = EmotionalTrackingService()
        let now = Date()
        var emotions: [DailyEmotion] = []
        for i in 0..<6 {
            let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: now)!
            let mood: EmotionalMood = i < 3 ? .sad : .happy
            emotions.append(DailyEmotion(date: Calendar.current.startOfDay(for: date), dominant: mood, confidence: 0.8))
        }
        let model = AIEmotionalModel(recentEmotions: emotions, totalSessions: 10)
        let signal = EmotionSignal(mood: .happy, confidence: 0.9)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.moodTrend == .improving, "mood trend should be improving, got \(updated.moodTrend)")
    }

    func moodTrendStable() {
        let service = EmotionalTrackingService()
        let now = Date()
        var emotions: [DailyEmotion] = []
        for i in 0..<6 {
            let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: now)!
            emotions.append(DailyEmotion(date: Calendar.current.startOfDay(for: date), dominant: .neutral, confidence: 0.6))
        }
        let model = AIEmotionalModel(recentEmotions: emotions, totalSessions: 10)
        let signal = EmotionSignal(mood: .neutral, confidence: 0.6)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.moodTrend == .stable, "mood trend should be stable, got \(updated.moodTrend)")
    }

    func moodTrendUnknownWithFewEmotions() {
        let service = EmotionalTrackingService()
        let model = AIEmotionalModel()
        let signal = EmotionSignal(mood: .happy, confidence: 0.8)
        let updated = service.updateAfterSession(signals: [signal], model: model)

        expect(updated.moodTrend == .unknown, "trend should be unknown with few emotions, got \(updated.moodTrend)")
    }

    // MARK: - 2.4 Relationship Phase

    func relationshipPhaseStrangerToFamiliar() {
        let service = EmotionalTrackingService()
        let model = AIEmotionalModel(relationshipPhase: .stranger, totalSessions: 9)
        let updated = service.updateAfterSession(signals: [], model: model)
        expect(updated.totalSessions == 10, "should be 10 sessions")
        expect(updated.relationshipPhase == .familiar, "should evolve to familiar, got \(updated.relationshipPhase)")
    }

    func relationshipPhaseFamiliarToClose() {
        let service = EmotionalTrackingService()
        let patterns = (0..<3).map { i in
            EmotionalPattern(pattern: "p\(i)", confidence: 0.7, evidence: 3)
        }
        let model = AIEmotionalModel(
            emotionalPatterns: patterns,
            relationshipPhase: .familiar,
            totalSessions: 29
        )
        let updated = service.updateAfterSession(signals: [], model: model)
        expect(updated.totalSessions == 30, "should be 30 sessions")
        expect(updated.relationshipPhase == .close, "should evolve to close, got \(updated.relationshipPhase)")
    }

    func relationshipPhaseCloseToBonded() {
        let service = EmotionalTrackingService()
        let patterns = (0..<6).map { i in
            EmotionalPattern(pattern: "p\(i)", confidence: 0.8, evidence: 5)
        }
        let model = AIEmotionalModel(
            emotionalPatterns: patterns,
            relationshipPhase: .close,
            totalSessions: 59
        )
        let updated = service.updateAfterSession(signals: [], model: model)
        expect(updated.totalSessions == 60, "should be 60 sessions")
        expect(updated.relationshipPhase == .bonded, "should evolve to bonded, got \(updated.relationshipPhase)")
    }

    func relationshipPhaseNoRegress() {
        let service = EmotionalTrackingService()
        let bonded = AIEmotionalModel(relationshipPhase: .bonded, totalSessions: 1)
        let updated = service.updateAfterSession(signals: [], model: bonded)
        expect(updated.relationshipPhase == .bonded, "bonded should not regress")
    }

    // MARK: - shouldRecalculatePatterns

    func shouldRecalculatePatterns() {
        let service = EmotionalTrackingService()
        let model5 = AIEmotionalModel(totalSessions: 5)
        expect(service.shouldRecalculatePatterns(model: model5), "should recalculate at 5 sessions")

        let model10 = AIEmotionalModel(totalSessions: 10)
        expect(service.shouldRecalculatePatterns(model: model10), "should recalculate at 10 sessions")
    }

    func shouldNotRecalculatePatterns() {
        let service = EmotionalTrackingService()
        let model3 = AIEmotionalModel(totalSessions: 3)
        expect(!service.shouldRecalculatePatterns(model: model3), "should not recalculate at 3 sessions")

        let model0 = AIEmotionalModel(totalSessions: 0)
        expect(!service.shouldRecalculatePatterns(model: model0), "should not recalculate at 0 sessions")

        let model7 = AIEmotionalModel(totalSessions: 7)
        expect(!service.shouldRecalculatePatterns(model: model7), "should not recalculate at 7 sessions")
    }

    // MARK: - 2.5 Crisis Detection

    func detectCrisisSignalPositive() {
        let service = EmotionalTrackingService()
        expect(service.detectCrisisSignal(from: "我不想活了"), "should detect 不想活")
        expect(service.detectCrisisSignal(from: "我想自杀"), "should detect 自杀")
        expect(service.detectCrisisSignal(from: "想死"), "should detect 想死")
        expect(service.detectCrisisSignal(from: "I want to kill myself"), "should detect kill myself")
        expect(service.detectCrisisSignal(from: "生活没有意义了"), "should detect 没有意义")
        expect(service.detectCrisisSignal(from: "活不下去了"), "should detect 活不下去")
    }

    func detectCrisisSignalNegative() {
        let service = EmotionalTrackingService()
        expect(!service.detectCrisisSignal(from: "今天天气真好"), "should not detect normal text")
        expect(!service.detectCrisisSignal(from: "我好开心啊"), "should not detect happy text")
        expect(!service.detectCrisisSignal(from: "工作有点累"), "should not detect tired text")
    }
}
