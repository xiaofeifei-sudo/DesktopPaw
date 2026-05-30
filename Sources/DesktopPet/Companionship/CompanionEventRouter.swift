import Foundation

@MainActor
public protocol CompanionEventRouting: AnyObject {
    func handle(_ event: CompanionEvent, runtimeState: PetRuntimeState) -> CompanionEventResult
    func context(runtimeState: PetRuntimeState) -> CompanionContext
    func switchPet(id: String, displayName: String)
    func resetRelationship(runtimeState: PetRuntimeState) -> CompanionEventResult
}

public struct CompanionEventResult: Equatable, Sendable {
    public let relationshipUpdate: RelationshipUpdate?
    public let generatedEvents: [CompanionEvent]
    public let shouldRefreshSettings: Bool

    public init(
        relationshipUpdate: RelationshipUpdate? = nil,
        generatedEvents: [CompanionEvent] = [],
        shouldRefreshSettings: Bool = false
    ) {
        self.relationshipUpdate = relationshipUpdate
        self.generatedEvents = generatedEvents
        self.shouldRefreshSettings = shouldRefreshSettings
    }
}

@MainActor
public final class CompanionEventRouter: CompanionEventRouting {
    private static let longAbsenceMinimumDays = 2

    private var currentPetId: String
    private var currentPetDisplayName: String
    private var lastCompanionEvent: CompanionEvent?

    private let relationshipStore: RelationshipStoring
    private let relationshipService: RelationshipService
    private let preferencesStore: CompanionPreferencesStoring
    private let clock: CompanionClock

    public init(
        petId: String,
        petDisplayName: String,
        relationshipStore: RelationshipStoring,
        preferencesStore: CompanionPreferencesStoring,
        clock: CompanionClock = SystemCompanionClock()
    ) {
        self.currentPetId = petId
        self.currentPetDisplayName = petDisplayName
        self.relationshipStore = relationshipStore
        self.relationshipService = RelationshipService(store: relationshipStore)
        self.preferencesStore = preferencesStore
        self.clock = clock
    }

    public func handle(_ event: CompanionEvent, runtimeState: PetRuntimeState) -> CompanionEventResult {
        switch event {
        case .appBecameVisible(let date):
            return handleAppBecameVisible(at: date, runtimeState: runtimeState)

        default:
            let result = handleRelationshipEvent(event, runtimeState: runtimeState)
            lastCompanionEvent = result.generatedEvents.last ?? event
            return result
        }
    }

    public func context(runtimeState: PetRuntimeState) -> CompanionContext {
        let preferences = preferencesStore.loadPreferences()
        let relationshipState = loadRelationshipState()

        return CompanionContext(
            petId: currentPetId,
            petDisplayName: currentPetDisplayName,
            petNickname: preferences.petNicknamesByPetId[currentPetId],
            userNickname: preferences.userNickname,
            runtimeState: runtimeState,
            relationship: relationshipState.snapshot,
            preferences: preferences,
            timeSlots: CompanionTimeSlot.slots(for: clock.now, calendar: clock.calendar),
            recentBubbleTexts: relationshipState.summary.recentBubbleTexts,
            lastCompanionEvent: lastCompanionEvent
        )
    }

    public func switchPet(id: String, displayName: String) {
        currentPetId = id
        currentPetDisplayName = displayName
        lastCompanionEvent = nil
    }

    public func resetRelationship(runtimeState: PetRuntimeState) -> CompanionEventResult {
        do {
            _ = try relationshipService.reset(petId: currentPetId)
            lastCompanionEvent = nil
            return CompanionEventResult(shouldRefreshSettings: true)
        } catch {
            return CompanionEventResult()
        }
    }

    private func handleAppBecameVisible(at date: Date, runtimeState: PetRuntimeState) -> CompanionEventResult {
        let dailyEvent = CompanionEvent.dailyFirstVisit(date)
        let dailyResult = handleRelationshipEvent(dailyEvent, runtimeState: runtimeState)
        var generatedEvents: [CompanionEvent] = []
        var latestUpdate = dailyResult.relationshipUpdate
        var shouldRefreshSettings = dailyResult.shouldRefreshSettings

        if dailyResult.relationshipUpdate != nil {
            generatedEvents.append(dailyEvent)
            generatedEvents.append(contentsOf: dailyResult.generatedEvents)
        }

        if let previousVisitDate = dailyResult.relationshipUpdate?.previousState.lastVisitDate,
           let absenceDays = longAbsenceDays(from: previousVisitDate, to: date) {
            let absenceEvent = CompanionEvent.longAbsenceReturned(days: absenceDays, date)
            let absenceResult = handleRelationshipEvent(absenceEvent, runtimeState: runtimeState)

            if absenceResult.relationshipUpdate != nil {
                generatedEvents.append(absenceEvent)
                generatedEvents.append(contentsOf: absenceResult.generatedEvents)
                latestUpdate = absenceResult.relationshipUpdate
                shouldRefreshSettings = true
            }
        }

        lastCompanionEvent = generatedEvents.last ?? .appBecameVisible(date)
        return CompanionEventResult(
            relationshipUpdate: latestUpdate,
            generatedEvents: generatedEvents,
            shouldRefreshSettings: shouldRefreshSettings
        )
    }

    private func handleRelationshipEvent(
        _ event: CompanionEvent,
        runtimeState: PetRuntimeState
    ) -> CompanionEventResult {
        do {
            let update = try relationshipService.handle(
                event: event,
                petId: currentPetId,
                context: RelationshipRuleContext(runtimeState: runtimeState, calendar: clock.calendar)
            )

            guard update.state != update.previousState else {
                return CompanionEventResult()
            }

            return CompanionEventResult(
                relationshipUpdate: update,
                generatedEvents: update.generatedEvents,
                shouldRefreshSettings: true
            )
        } catch {
            return CompanionEventResult()
        }
    }

    private func loadRelationshipState() -> RelationshipState {
        (try? relationshipStore.loadState(petId: currentPetId)) ?? RelationshipState()
    }

    private func longAbsenceDays(from previousVisitDate: Date, to date: Date) -> Int? {
        let startOfPreviousVisit = clock.calendar.startOfDay(for: previousVisitDate)
        let startOfCurrentVisit = clock.calendar.startOfDay(for: date)
        let days = clock.calendar.dateComponents([.day], from: startOfPreviousVisit, to: startOfCurrentVisit).day ?? 0

        return days >= Self.longAbsenceMinimumDays ? days : nil
    }
}
