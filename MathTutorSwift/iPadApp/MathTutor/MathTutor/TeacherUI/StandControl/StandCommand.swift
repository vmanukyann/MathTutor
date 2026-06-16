import Foundation

enum StandCommand: String, CaseIterable, Identifiable, Sendable {
    case observeMode
    case teachMode
    case center
    case pitchDownToPaper
    case pitchUpToStudent
    case stop
    case returnToObserve

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .observeMode: "Observe Mode"
        case .teachMode: "Teach Mode"
        case .center: "Center"
        case .pitchDownToPaper: "Pitch Down"
        case .pitchUpToStudent: "Pitch Up"
        case .stop: "Emergency Stop"
        case .returnToObserve: "Return to Observe"
        }
    }

    var systemImage: String {
        switch self {
        case .observeMode, .returnToObserve: "camera.viewfinder"
        case .teachMode: "rectangle.inset.filled.and.person.filled"
        case .center: "scope"
        case .pitchDownToPaper: "arrow.down.forward.circle.fill"
        case .pitchUpToStudent: "arrow.up.forward.circle.fill"
        case .stop: "stop.circle.fill"
        }
    }

    var httpPath: String {
        switch self {
        case .observeMode, .returnToObserve: "/observe"
        case .teachMode: "/teach"
        case .center: "/center"
        case .pitchDownToPaper: "/pitch-down"
        case .pitchUpToStudent: "/pitch-up"
        case .stop: "/stop"
        }
    }
}
