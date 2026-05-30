import Foundation
import DesktopPet

@MainActor
func runAIVisualSafetyServiceTests() {
    let tests = AIVisualSafetyServiceTests()
    tests.textSafetyViolationRejected()
    tests.nsfwContentRejected()
    tests.realPersonRejected()
    tests.violenceOrGoreRejected()
    tests.professionalContentRejected()
    tests.sensitiveIdentityRejected()
    tests.safeContentAllowed()
    tests.speciesChangeUpgradedToHighImpact()
    tests.bodyTypeChangeUpgradedToHighImpact()
    tests.styleChangeUpgradedToHighImpact()
    tests.lowImpactStaysLowForSafeContent()
    tests.sanitizePromptReturnsConsistencyPrompt()
    tests.customTextSafetyServiceInjected()
    tests.allRejectionCategoriesHaveUserFacingText()
    tests.safetyServiceNoNetworkDependency()
    tests.emptyDescriptionAllowed()
    tests.mediumImpactUnchangedWhenNoUpgradeMatch()
}

@MainActor
private struct AIVisualSafetyServiceTests {
    private let service = AIVisualSafetyService()

    private func makeCandidate(
        description: String,
        impact: AIVisualActionImpact = .low,
        kind: AIVisualActionKind = .expression
    ) -> AIVisualActionCandidate {
        AIVisualActionCandidate(
            id: "test-\(UUID().uuidString)",
            petId: "pet-1",
            source: .chat,
            kind: kind,
            description: description,
            renderMode: .replaceWholeImage,
            requestedDurationSeconds: 60,
            impact: impact
        )
    }

    func textSafetyViolationRejected() {
        let candidate = makeCandidate(description: "帮我治病的样子")
        let result = service.validate(candidate: candidate)
        expect(!result.isAllowed, "text safety violation should be rejected")
        expect(result.rejectionReason == .textSafetyViolation, "should be text safety rejection")
        expect(result.userFacingText != nil, "should have user-facing text")
    }

    func nsfwContentRejected() {
        let descriptions = ["裸体", "色情", "性感", "暴露", "成人内容"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(!result.isAllowed, "'\(desc)' should be rejected as NSFW")
            expect(result.rejectionReason == .nsfwContent, "'\(desc)' should be nsfw rejection")
        }
    }

    func realPersonRejected() {
        let descriptions = ["真人", "明星", "名人", "变成真人"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(!result.isAllowed, "'\(desc)' should be rejected as real person")
            expect(result.rejectionReason == .realPersonOrIdentity, "'\(desc)' should be identity rejection")
        }
    }

    func violenceOrGoreRejected() {
        let descriptions = ["血腥", "流血", "断肢", "内脏"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(!result.isAllowed, "'\(desc)' should be rejected as violence")
            expect(result.rejectionReason == .violenceOrGore, "'\(desc)' should be violence rejection")
        }
    }

    func professionalContentRejected() {
        let descriptions = ["诊断报告", "医疗图像", "手术", "法律文件", "处方"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(!result.isAllowed, "'\(desc)' should be rejected as professional content")
            expect(result.rejectionReason == .professionalVisualization, "'\(desc)' should be professional rejection")
        }
    }

    func sensitiveIdentityRejected() {
        let descriptions = ["军装", "警服", "恐怖分子"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(!result.isAllowed, "'\(desc)' should be rejected as sensitive identity")
            expect(result.rejectionReason == .sensitiveIdentity, "'\(desc)' should be sensitive identity rejection")
        }
    }

    func safeContentAllowed() {
        let descriptions = [
            "开心的表情",
            "戴着小帽子",
            "坐在草地上",
            "柔和的光晕",
            "挥挥手",
            "抱着小枕头",
        ]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(result.isAllowed, "'\(desc)' should be allowed")
            expect(result.rejectionReason == nil, "'\(desc)' should have no rejection reason")
        }
    }

    func speciesChangeUpgradedToHighImpact() {
        let descriptions = ["变成猫", "变成狗", "变成动物", "换物种"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc, impact: .low)
            let result = service.validate(candidate: candidate)
            expect(result.isAllowed, "'\(desc)' should be allowed but upgraded")
            expect(result.impact == .high, "'\(desc)' should upgrade to high impact")
            expect(result.requiresConfirmation, "'\(desc)' should require confirmation")
        }
    }

    func bodyTypeChangeUpgradedToHighImpact() {
        let descriptions = ["变胖", "变瘦", "变大", "变小"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc, impact: .low)
            let result = service.validate(candidate: candidate)
            expect(result.isAllowed, "'\(desc)' should be allowed but upgraded")
            expect(result.impact == .high, "'\(desc)' should upgrade to high impact")
            expect(result.requiresConfirmation, "'\(desc)' should require confirmation")
        }
    }

    func styleChangeUpgradedToHighImpact() {
        let descriptions = ["写实风格", "照片风格"]
        for desc in descriptions {
            let candidate = makeCandidate(description: desc, impact: .low)
            let result = service.validate(candidate: candidate)
            expect(result.isAllowed, "'\(desc)' should be allowed but upgraded")
            expect(result.impact == .high, "'\(desc)' should upgrade to high impact")
        }
    }

    func lowImpactStaysLowForSafeContent() {
        let candidate = makeCandidate(description: "开心的表情", impact: .low)
        let result = service.validate(candidate: candidate)
        expect(result.impact == .low, "safe content should keep low impact")
        expect(!result.requiresConfirmation, "safe low impact should not require confirmation")
    }

    func sanitizePromptReturnsConsistencyPrompt() {
        let prompt = service.sanitizePrompt("戴一顶小红帽", petDescriptor: "一只白色小猫")
        expect(prompt.contains("Create a single desktop pet visual variation"), "should contain consistency header")
        expect(prompt.contains("一只白色小猫"), "should contain pet descriptor")
        expect(prompt.contains("戴一顶小红帽"), "should contain description")
        expect(prompt.contains("Keep the same pet identity"), "should contain identity constraint")
        expect(prompt.contains("no text, no watermark, no extra characters"), "should contain quality constraint")
        expect(prompt.contains("clean plain or transparent-looking background"), "should contain background constraint")
        expect(prompt.contains("suitable for a small macOS desktop pet"), "should contain platform constraint")
    }

    func customTextSafetyServiceInjected() {
        let customTextService = MockTextSafetyService(shouldBlock: true)
        let customService = AIVisualSafetyService(textSafetyService: customTextService)
        let candidate = makeCandidate(description: "开心的表情")
        let result = customService.validate(candidate: candidate)
        expect(!result.isAllowed, "custom blocking service should reject")
        expect(result.rejectionReason == .textSafetyViolation, "should be text safety rejection")
    }

    func allRejectionCategoriesHaveUserFacingText() {
        let service = AIVisualSafetyService()
        let testCases: [(String, AIVisualSafetyRejection)] = [
            ("裸体", .nsfwContent),
            ("真人", .realPersonOrIdentity),
            ("血腥", .violenceOrGore),
            ("手术", .professionalVisualization),
            ("军装", .sensitiveIdentity),
        ]
        for (desc, expectedCategory) in testCases {
            let candidate = makeCandidate(description: desc)
            let result = service.validate(candidate: candidate)
            expect(result.rejectionReason == expectedCategory, "'\(desc)' should be \(expectedCategory)")
            expect(result.userFacingText != nil, "rejection should have user-facing text for \(desc)")
            expect(!result.userFacingText!.isEmpty, "user-facing text should not be empty for \(desc)")
        }
    }

    func safetyServiceNoNetworkDependency() {
        let service = AIVisualSafetyService()
        let candidate = makeCandidate(description: "开心的表情")
        let result = service.validate(candidate: candidate)
        expect(result.isAllowed, "validation should work without network")
        let prompt = service.sanitizePrompt("开心", petDescriptor: "")
        expect(!prompt.isEmpty, "sanitize should work without network")
    }

    func emptyDescriptionAllowed() {
        let candidate = makeCandidate(description: "")
        let result = service.validate(candidate: candidate)
        expect(result.isAllowed, "empty description should be allowed")
    }

    func mediumImpactUnchangedWhenNoUpgradeMatch() {
        let candidate = makeCandidate(description: "温和的表情", impact: .medium)
        let result = service.validate(candidate: candidate)
        expect(result.isAllowed, "safe medium should be allowed")
        expect(result.impact == .medium, "safe content should keep medium impact")
        expect(!result.requiresConfirmation, "medium impact without upgrade should not require confirmation")
    }
}

private final class MockTextSafetyService: AISafetyServicing, @unchecked Sendable {
    private let block: Bool

    init(shouldBlock: Bool) {
        self.block = shouldBlock
    }

    func classifyRisk(content: String) -> AIRiskLevel {
        block ? .high : .safe
    }

    func shouldBlock(content: String) -> Bool { block }

    func safeResponse(for riskLevel: AIRiskLevel, category: AISafetyCategory?) -> String {
        "mock response"
    }

    func validatePromptSafety(_ prompt: String) -> AISafetyCheckResult {
        AISafetyCheckResult(riskLevel: block ? .high : .safe, shouldBlock: block)
    }
}
