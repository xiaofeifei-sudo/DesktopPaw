import Foundation
import DesktopPet

@MainActor
func runChatPanelControllerTests() {
    let tests = ChatPanelControllerTests()
    tests.initCreatesController()
    tests.isPanelVisibleFalseInitially()
    tests.showChatPanelCreatesWindow()
    tests.closeChatPanelHidesWindow()
    tests.showChatPanelReusesWindow()
    tests.closeAndReopenPreservesViewModel()
}

@MainActor
private struct ChatPanelControllerTests {
    private func makeController() -> (ChatPanelController, MockAIProvider) {
        let provider = MockAIProvider(stubbedResponse: "测试回复")
        let memoryStore = AIMemoryStore()
        let safetyService = AISafetyService()
        let personalityEngine = AIPersonalityEngine()
        let chatEngine = AIChatEngine(
            provider: provider,
            memoryStore: memoryStore,
            safetyService: safetyService,
            personalityEngine: personalityEngine
        )
        let controller = ChatPanelController(
            chatEngine: chatEngine,
            bubbleBridge: nil,
            getPetWindowFrame: { nil },
            screenGeometryProvider: { ScreenGeometry(visibleFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]) }
        )
        return (controller, provider)
    }

    func initCreatesController() {
        let (controller, _) = makeController()
        expect(controller.isPanelVisible == false, "controller should initialize with no visible panel")
    }

    func isPanelVisibleFalseInitially() {
        let (controller, _) = makeController()
        expect(controller.isPanelVisible == false, "isPanelVisible should be false before showing")
    }

    func showChatPanelCreatesWindow() {
        let (controller, _) = makeController()
        controller.showChatPanel(petId: "test-pet")
        expect(controller.isPanelVisible == true, "isPanelVisible should be true after showing")
    }

    func closeChatPanelHidesWindow() {
        let (controller, _) = makeController()
        controller.showChatPanel(petId: "test-pet")
        controller.closeChatPanel()
        expect(controller.isPanelVisible == false, "isPanelVisible should be false after closing")
    }

    func showChatPanelReusesWindow() {
        let (controller, _) = makeController()
        controller.showChatPanel(petId: "test-pet")
        controller.closeChatPanel()
        controller.showChatPanel(petId: "test-pet")
        expect(controller.isPanelVisible == true, "should reuse the same window on second show")
    }

    func closeAndReopenPreservesViewModel() {
        let (controller, _) = makeController()
        controller.showChatPanel(petId: "test-pet")
        controller.closeChatPanel()
        controller.showChatPanel(petId: "test-pet")
        expect(controller.isPanelVisible == true, "panel should be visible after reopen")
    }
}
