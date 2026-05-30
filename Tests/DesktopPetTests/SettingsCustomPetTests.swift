import Foundation
import DesktopPet

@MainActor
func runSettingsCustomPetTests() {
  let tests = SettingsCustomPetTests()
  tests.bubbleSettingsHaveSensibleDefaults()
  tests.setSpeechBubbleEnabledFiresCallback()
  tests.setSpeechBubbleEnabledIsIdempotent()
  tests.setBubbleFrequencyFiresCallback()
  tests.setBubbleFrequencyIsIdempotent()
  tests.updateSpeechBubbleEnabledAppliesWithoutCallback()
  tests.updateBubbleFrequencyAppliesWithoutCallback()
  tests.initialBubbleFrequencyOverrideIsRespected()
}

@MainActor
private struct SettingsCustomPetTests {
  func bubbleSettingsHaveSensibleDefaults() {
    let model = SettingsViewModel()
    expect(model.isSpeechBubbleEnabled, "default speech bubble should be enabled")
    expect(model.bubbleFrequency == .normal, "default bubble frequency should be normal")
  }

  func setSpeechBubbleEnabledFiresCallback() {
    let model = SettingsViewModel(isSpeechBubbleEnabled: true)
    var observed: [Bool] = []
    model.onSpeechBubbleEnabledChanged = { observed.append($0) }
    model.setSpeechBubbleEnabled(false)
    expect(observed == [false], "callback should fire with new value")
    expect(model.isSpeechBubbleEnabled == false, "state should reflect new value")
  }

  func setSpeechBubbleEnabledIsIdempotent() {
    let model = SettingsViewModel(isSpeechBubbleEnabled: true)
    var fired = 0
    model.onSpeechBubbleEnabledChanged = { _ in fired += 1 }
    model.setSpeechBubbleEnabled(true)
    expect(fired == 0, "setting same value should not fire callback")
  }

  func setBubbleFrequencyFiresCallback() {
    let model = SettingsViewModel()
    var observed: [BubbleFrequency] = []
    model.onBubbleFrequencyChanged = { observed.append($0) }
    model.setBubbleFrequency(.expressive)
    expect(observed == [.expressive], "callback should fire with new frequency")
    expect(model.bubbleFrequency == .expressive, "state should reflect new frequency")
  }

  func setBubbleFrequencyIsIdempotent() {
    let model = SettingsViewModel(bubbleFrequency: .quiet)
    var fired = 0
    model.onBubbleFrequencyChanged = { _ in fired += 1 }
    model.setBubbleFrequency(.quiet)
    expect(fired == 0, "setting same frequency should not refire callback")
  }

  func updateSpeechBubbleEnabledAppliesWithoutCallback() {
    let model = SettingsViewModel(isSpeechBubbleEnabled: true)
    var fired = 0
    model.onSpeechBubbleEnabledChanged = { _ in fired += 1 }
    model.updateSpeechBubbleEnabled(false)
    expect(model.isSpeechBubbleEnabled == false, "external sync should update state")
    expect(fired == 0, "external sync should not refire callback")
  }

  func updateBubbleFrequencyAppliesWithoutCallback() {
    let model = SettingsViewModel(bubbleFrequency: .normal)
    var fired = 0
    model.onBubbleFrequencyChanged = { _ in fired += 1 }
    model.updateBubbleFrequency(.expressive)
    expect(model.bubbleFrequency == .expressive, "external sync should update state")
    expect(fired == 0, "external sync should not refire callback")
  }

  func initialBubbleFrequencyOverrideIsRespected() {
    let model = SettingsViewModel(isSpeechBubbleEnabled: false, bubbleFrequency: .quiet)
    expect(model.isSpeechBubbleEnabled == false, "initializer should accept speech bubble override")
    expect(model.bubbleFrequency == .quiet, "initializer should accept frequency override")
  }
}
