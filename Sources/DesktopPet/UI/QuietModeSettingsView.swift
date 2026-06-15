import SwiftUI

@MainActor
public struct QuietModeSettingsView: View {
    @ObservedObject private var model: CompanionshipSettingsViewModel

    public init(model: CompanionshipSettingsViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L10n.Companionship.quietHours, isOn: Binding(
                get: { model.preferences.quietHours != nil },
                set: { model.setQuietHoursEnabled($0) }
            ))

            if model.preferences.quietHours != nil {
                HStack {
                    Text(L10n.Companionship.from)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { minuteToDate(model.preferences.quietHours?.startMinuteOfDay ?? 0) },
                            set: { model.setQuietHoursStart(dateToMinute($0)) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()

                    Text(L10n.Companionship.to)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { minuteToDate(model.preferences.quietHours?.endMinuteOfDay ?? 0) },
                            set: { model.setQuietHoursEnd(dateToMinute($0)) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                if model.isQuietActive {
                    Text(L10n.Companionship.quietActive)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if model.isQuietActive {
                Button(L10n.Companionship.resumeBubblesNow) {
                    model.clearQuietMode()
                }
            } else {
                Button(L10n.Companionship.quietForOneHour) {
                    model.quietForOneHour()
                }
            }
        }
    }
}

private func minuteToDate(_ minute: Int) -> Date {
    let hour = minute / 60
    let min = minute % 60
    var components = DateComponents()
    components.hour = hour
    components.minute = min
    return Calendar.current.date(from: components) ?? Date()
}

private func dateToMinute(_ date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
}
