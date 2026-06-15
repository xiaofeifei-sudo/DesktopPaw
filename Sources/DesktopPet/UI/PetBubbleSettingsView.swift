import SwiftUI

@MainActor
public struct PetBubbleSettingsView: View {
  @ObservedObject private var model: SettingsViewModel

  public init(model: SettingsViewModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(
        L10n.Bubble.showSpeechBubbles,
        isOn: Binding(
          get: { model.isSpeechBubbleEnabled },
          set: { model.setSpeechBubbleEnabled($0) }
        )
      )

      Picker(
        L10n.Bubble.frequency,
        selection: Binding(
          get: { model.bubbleFrequency },
          set: { model.setBubbleFrequency($0) }
        )
      ) {
        ForEach(BubbleFrequency.allCases, id: \.self) { freq in
          Text(label(for: freq)).tag(freq)
        }
      }
      .pickerStyle(.segmented)
      .disabled(!model.isSpeechBubbleEnabled)
    }
  }

  private func label(for frequency: BubbleFrequency) -> String {
    switch frequency {
    case .quiet: return L10n.Bubble.frequencyQuiet
    case .normal: return L10n.Bubble.frequencyNormal
    case .expressive: return L10n.Bubble.frequencyExpressive
    }
  }
}
