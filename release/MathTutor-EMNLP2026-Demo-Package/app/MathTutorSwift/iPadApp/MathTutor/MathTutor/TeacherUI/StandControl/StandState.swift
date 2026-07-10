import Foundation

enum StandMode: String, Codable, Sendable {
    case observe
    case teach
    case moving
    case stopped
    case error

    var displayName: String {
        switch self {
        case .observe: "Observe"
        case .teach: "Teach"
        case .moving: "Moving"
        case .stopped: "Stopped"
        case .error: "Error"
        }
    }
}

enum StandConnectionMode: String, Sendable {
    case simulated
    case http

    var displayName: String {
        switch self {
        case .simulated: "Simulated"
        case .http: "HTTP"
        }
    }
}

struct StandState: Equatable, Sendable {
    var currentMode: StandMode = .observe
    var lastCommand: StandCommand?
    var isMoving = false
    var lastError: String?
    var simulatedAngleDegrees = -35.0

    var modeDescription: String {
        if isMoving {
            return "Moving"
        }
        return currentMode.displayName
    }
}
