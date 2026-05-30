import Foundation

// MARK: - Protocols

public protocol ContextualBubblePhraseProviding: Sendable {
    func phrase(for trigger: BubbleTrigger, context: CompanionContext, now: Date) -> BubblePhraseSelection?
}

public struct BubblePhraseSelection: Equatable, Sendable {
    public let phrase: BubblePhrase
    public let renderedText: String
    public let microDialog: MicroDialog?

    public init(phrase: BubblePhrase, renderedText: String, microDialog: MicroDialog? = nil) {
        self.phrase = phrase
        self.renderedText = renderedText
        self.microDialog = microDialog
    }
}

// MARK: - Phrase cooldown tracking

public protocol PhraseCooldownTracking: Sendable {
    func canUse(phraseId: String, at date: Date) -> Bool
    func recordUse(phraseId: String, at date: Date)
}

public final class InMemoryPhraseCooldownTracker: PhraseCooldownTracking, @unchecked Sendable {
    private var lastUsedByPhraseId: [String: Date] = [:]
    private let catalog: BubblePhraseCatalog

    public init(catalog: BubblePhraseCatalog) {
        self.catalog = catalog
    }

    public func canUse(phraseId: String, at date: Date) -> Bool {
        guard let lastUsed = lastUsedByPhraseId[phraseId] else {
            return true
        }
        guard let cooldown = catalog.phrase(withId: phraseId)?.cooldownSeconds else {
            return true
        }
        return date.timeIntervalSince(lastUsed) >= cooldown
    }

    public func recordUse(phraseId: String, at date: Date) {
        lastUsedByPhraseId[phraseId] = date
    }
}

// MARK: - Provider

public struct ContextualBubblePhraseProvider: ContextualBubblePhraseProviding {
    private let catalog: BubblePhraseCatalog
    private let phraseCooldownTracker: (any PhraseCooldownTracking)?
    private let quietModePolicy: (any QuietModeEvaluating)?
    private let randomProvider: @Sendable (ClosedRange<Double>) -> Double

    public init(
        catalog: BubblePhraseCatalog,
        phraseCooldownTracker: (any PhraseCooldownTracking)? = nil,
        quietModePolicy: (any QuietModeEvaluating)? = nil,
        randomProvider: @escaping @Sendable (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        self.catalog = catalog
        self.phraseCooldownTracker = phraseCooldownTracker
        self.quietModePolicy = quietModePolicy
        self.randomProvider = randomProvider
    }

    public func phrase(for trigger: BubbleTrigger, context: CompanionContext, now: Date = Date()) -> BubblePhraseSelection? {

        // Step 1: Filter by trigger match
        var candidates = catalog.phrases(for: trigger)

        // Step 2: Filter by relationship level
        let level = context.relationship.currentLevel
        candidates = candidates.filter { $0.matchesRelationshipLevel(level) }

        // Step 3: Filter by time slots
        candidates = candidates.filter { $0.matchesTimeSlots(context.timeSlots) }

        // Step 4: Filter by mood tags
        let currentMoodTags = moodTags(from: context.runtimeState)
        candidates = candidates.filter { $0.matchesMood(currentMoodTags) }

        // Step 5: Quiet mode filter
        let isQuiet: Bool
        if let policy = quietModePolicy {
            isQuiet = policy.quietState(preferences: context.preferences, at: now) != .inactive
        } else {
            isQuiet = (context.preferences.quietUntil.map { $0 > now } ?? false)
                || context.preferences.quietHours?.isEnabled == true
        }
        if isQuiet {
            let quietSuppressed: Set<BubbleTrigger> = [
                .idle, .walking, .dailyGreeting,
                .longAbsenceReturn, .relationshipLevelUp, .microDialogPrompt
            ]
            candidates = candidates.filter { phrase in
                quietSuppressed.isDisjoint(with: phrase.triggers)
            }
        }

        // Step 6: Relationship prompts toggle
        if !context.preferences.showRelationshipPrompts {
            let suppressed: Set<BubbleTrigger> = [.relationshipLevelUp, .longAbsenceReturn]
            candidates = candidates.filter { phrase in
                suppressed.isDisjoint(with: phrase.triggers)
            }
        }

        // Cooldown filter
        if let tracker = phraseCooldownTracker {
            candidates = candidates.filter { tracker.canUse(phraseId: $0.id, at: now) }
        }

        guard !candidates.isEmpty else { return nil }

        // Step 7: Calculate adjusted weights for deduplication
        let recentSet = Set(context.recentBubbleTexts)
        let weightedCandidates = candidates.map { phrase -> (phrase: BubblePhrase, adjustedWeight: Double) in
            let adjusted = recentSet.contains(phrase.text) ? max(0, phrase.weight - 0.3) : phrase.weight
            return (phrase, adjusted)
        }

        // Step 8: Weighted random selection
        let totalWeight = weightedCandidates.reduce(0.0) { $0 + $1.adjustedWeight }
        guard totalWeight > 0 else { return nil }

        let roll = randomProvider(0...totalWeight)
        var cumulative = 0.0
        var selected: BubblePhrase?
        for candidate in weightedCandidates {
            cumulative += candidate.adjustedWeight
            if roll <= cumulative {
                selected = candidate.phrase
                break
            }
        }

        guard let selected = selected ?? weightedCandidates.last?.phrase else {
            return nil
        }

        // Step 9: Render placeholders
        let rendered = renderText(selected.text, context: context)

        // Step 10: Length check — try next candidate if too long
        if !isValidLength(rendered) {
            var remaining = weightedCandidates.filter { $0.phrase.id != selected.id }
            while !remaining.isEmpty {
                let nextTotal = remaining.reduce(0.0) { $0 + $1.adjustedWeight }
                guard nextTotal > 0 else { return nil }
                let nextRoll = randomProvider(0...nextTotal)
                var nextCumulative = 0.0
                var nextSelected: BubblePhrase?
                for candidate in remaining {
                    nextCumulative += candidate.adjustedWeight
                    if nextRoll <= nextCumulative {
                        nextSelected = candidate.phrase
                        break
                    }
                }
                guard let next = nextSelected ?? remaining.last?.phrase else { return nil }
                let nextRendered = renderText(next.text, context: context)
                if isValidLength(nextRendered) {
                    phraseCooldownTracker?.recordUse(phraseId: next.id, at: now)
                    return BubblePhraseSelection(phrase: next, renderedText: nextRendered)
                }
                remaining.removeAll { $0.phrase.id == next.id }
            }
            return nil
        }

        // Record use for cooldown tracking
        phraseCooldownTracker?.recordUse(phraseId: selected.id, at: now)

        return BubblePhraseSelection(phrase: selected, renderedText: rendered)
    }

    // MARK: - Private helpers

    private func moodTags(from state: PetRuntimeState) -> Set<BubbleMoodTag> {
        var tags = Set<BubbleMoodTag>()
        if state.hunger >= 0.7 { tags.insert(.hungry) }
        if state.hunger <= 0.3 { tags.insert(.full) }
        if state.energy <= 0.3 { tags.insert(.tired) }
        if state.energy >= 0.7 { tags.insert(.energetic) }
        if state.mood >= 0.7 { tags.insert(.happy) }
        if state.mood <= 0.3 { tags.insert(.sad) }
        return tags
    }

    private func renderText(_ text: String, context: CompanionContext) -> String {
        let petName = context.petNickname ?? context.petDisplayName
        let userName = context.userNickname ?? ""
        var result = text.replacingOccurrences(of: "{pet}", with: petName)
        result = result.replacingOccurrences(of: "{user}", with: userName)
        return result
    }

    private func isValidLength(_ text: String) -> Bool {
        let chineseCount = text.unicodeScalars.filter {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value)
        }.count
        return chineseCount <= 12
    }
}
