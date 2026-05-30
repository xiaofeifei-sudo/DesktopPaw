import Foundation

// MARK: - D-3.1 Enums

public enum GenerationIntent: String, Codable, Sendable, Equatable {
    case subtleExpression
    case subtleAmbience
    case smallAccessory
    case themeVariation
    case creativeVariation

    public var actionKind: AIVisualActionKind {
        switch self {
        case .subtleExpression: return .expression
        case .subtleAmbience: return .ambience
        case .smallAccessory: return .accessory
        case .themeVariation, .creativeVariation: return .theme
        }
    }

    public static func defaultIntent(
        for source: AIVisualActionSource,
        preference: ConsistencyPreference
    ) -> GenerationIntent {
        switch source {
        case .userRequest:
            return .subtleAmbience
        case .chat, .smartBubble, .relationshipEvent:
            return preference == .creative ? .smallAccessory : .subtleAmbience
        }
    }
}

public enum ConsistencyPreference: String, CaseIterable, Codable, Sendable, Equatable {
    case conservative = "conservative"
    case balanced = "balanced"
    case creative = "creative"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ConsistencyPreference(rawValue: raw) ?? .conservative
    }

    public var displayName: String {
        switch self {
        case .conservative: return "保守优先"
        case .balanced: return "平衡"
        case .creative: return "创意优先"
        }
    }

    public var userDescription: String {
        switch self {
        case .conservative: return "尽量像原图，只做小变化"
        case .balanced: return "保持像原图，但允许明显配饰或氛围变化"
        case .creative: return "允许更明显主题变化，但仍不能变成新角色"
        }
    }
}

// MARK: - D-3.2 Prompt Strategy Result

public struct PromptStrategyResult: Equatable {
    public let corePrompt: String
    public let identityConstraints: [String]
    public let negativeConstraints: [String]
    public let styleGuidance: String?
    public let finalPrompt: String

    public init(
        corePrompt: String,
        identityConstraints: [String],
        negativeConstraints: [String],
        styleGuidance: String? = nil,
        finalPrompt: String
    ) {
        self.corePrompt = corePrompt
        self.identityConstraints = identityConstraints
        self.negativeConstraints = negativeConstraints
        self.styleGuidance = styleGuidance
        self.finalPrompt = finalPrompt
    }
}

// MARK: - D-3.3 Protocol

public protocol PromptStrategizing: Sendable {
    func buildPrompt(
        intent: GenerationIntent,
        petDescriptor: PetDescriptor,
        preference: ConsistencyPreference,
        actionKind: AIVisualActionKind
    ) -> PromptStrategyResult
}

// MARK: - Strategy Implementation

public final class PromptStrategy: PromptStrategizing, Sendable {
    private let maxPromptLength: Int

    public init(maxPromptLength: Int = 2000) {
        self.maxPromptLength = maxPromptLength
    }

    public func buildPrompt(
        intent: GenerationIntent,
        petDescriptor: PetDescriptor,
        preference: ConsistencyPreference,
        actionKind: AIVisualActionKind
    ) -> PromptStrategyResult {
        let core = buildCorePrompt(intent: intent)
        let identity = buildIdentityConstraints(petDescriptor)
        let negative = buildNegativeConstraints(preference: preference, intent: intent)
        let style = buildStyleGuidance(petDescriptor: petDescriptor)

        let finalPrompt = assemble(
            core: core,
            identity: identity,
            negative: negative,
            style: style,
            notes: petDescriptor.visualNotes
        )

        return PromptStrategyResult(
            corePrompt: core,
            identityConstraints: identity,
            negativeConstraints: negative,
            styleGuidance: style,
            finalPrompt: finalPrompt
        )
    }

    // MARK: - D-3.4 Intent → Prompt Template

    private func buildCorePrompt(intent: GenerationIntent) -> String {
        switch intent {
        case .subtleExpression:
            return "Make a subtle expression-only change to this desktop pet character. Keep the exact same character, colors, accessories, pose, outline, and art style."
        case .subtleAmbience:
            return "Add a subtle ambient effect around this desktop pet character. Do not change the character itself, only the surrounding atmosphere or mood."
        case .smallAccessory:
            return "Add a small accessory to this desktop pet character. Keep the character unchanged, only add the specified accessory."
        case .themeVariation:
            return "Create a themed variation of this desktop pet character. Keep the same character identity, species, main colors, and art style."
        case .creativeVariation:
            return "Create a creative variation of this desktop pet character. Maintain the core character identity and species while exploring a new direction."
        }
    }

    // MARK: - D-3.5 Identity Constraints from PetDescriptor

    private func buildIdentityConstraints(_ descriptor: PetDescriptor) -> [String] {
        var constraints: [String] = []

        if let species = descriptor.speciesHint {
            constraints.append("The character is a \(species)")
        }
        if let name = descriptor.nameHint {
            constraints.append("Named \"\(name)\"")
        }
        if let traits = descriptor.referenceImageTraits {
            if !traits.dominantColors.isEmpty {
                constraints.append("Main colors: \(traits.dominantColors.joined(separator: ", "))")
            }
            if let style = traits.estimatedStyle {
                constraints.append("Art style: \(style)")
            }
            if traits.width > 0, traits.height > 0 {
                constraints.append("Original size: \(traits.width)x\(traits.height)")
            }
            if traits.hasAlpha {
                constraints.append("Transparent sprite with no solid background")
            }
        }
        if !descriptor.learnedConstraints.isEmpty {
            constraints.append(contentsOf: descriptor.learnedConstraints)
        }

        return constraints
    }

    // MARK: - D-3.6 Negative Constraints by Preference

    private func buildNegativeConstraints(
        preference: ConsistencyPreference,
        intent: GenerationIntent
    ) -> [String] {
        var constraints: [String] = []

        switch preference {
        case .conservative:
            constraints = [
                "Do not redesign the character",
                "Do not change species, main colors, accessories, pose, outline, or art style",
                "Do not generate 3D, toy-like, realistic, or photorealistic output",
                "Preserve all visible accessories, patterns, and ornaments",
                "Do not add a solid or photographic background",
            ]
        case .balanced:
            constraints = [
                "Do not redesign the character",
                "Do not change species or core identity",
                "Do not generate 3D, toy-like, realistic, or photorealistic output",
                "Keep the overall art style direction",
            ]
        case .creative:
            constraints = [
                "Keep the same character species and identity",
                "Maintain the overall art style direction",
                "Do not change into a different character or species",
            ]
        }

        if intent == .subtleExpression || intent == .subtleAmbience {
            constraints.append("Do not change the character's body shape or proportions")
        }

        return constraints
    }

    // MARK: - D-3.7 Style Guidance + Visual Notes

    private func buildStyleGuidance(petDescriptor: PetDescriptor) -> String? {
        guard let traits = petDescriptor.referenceImageTraits,
              let style = traits.estimatedStyle else {
            return nil
        }
        return "Preserve the \(style) art style."
    }

    // MARK: - D-3.8 Prompt Assembly

    private func assemble(
        core: String,
        identity: [String],
        negative: [String],
        style: String?,
        notes: String?
    ) -> String {
        var parts: [String] = []

        parts.append(core)

        if !identity.isEmpty {
            parts.append("Character reference: " + identity.joined(separator: ". ") + ".")
        }

        if let notes, !notes.isEmpty {
            parts.append("User description: \(notes).")
        }

        if let style {
            parts.append(style)
        }

        if !negative.isEmpty {
            parts.append(negative.joined(separator: ". ") + ".")
        }

        parts.append("Use one centered character, no text, no watermark, no extra characters.")
        parts.append("Make it suitable for a small macOS desktop pet.")

        var prompt = parts.joined(separator: " ")

        if prompt.count > maxPromptLength {
            prompt = String(prompt.prefix(maxPromptLength))
        }

        return prompt
    }
}
