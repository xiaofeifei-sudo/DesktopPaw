import Foundation

public enum PetEvent: Equatable {
    case appLaunched
    case tick(Date)
    case clicked
    case pet
    case feed
    case dragStarted
    case dragEnded
    case sleepRequested
    case wakeRequested
}
