import Foundation

enum VoiceRouteLocation: Sendable {
    case studentPicker
    case consent
    case liveSession
    case teachMode
    case reflection
    case admin
}

struct VoiceRouteContext: Sendable {
    var location: VoiceRouteLocation
    var sessionStatus: SessionStatus?
    var canEnterTeachMode: Bool
    var holderControlsActive: Bool
}

enum VoiceRoutedAction: Equatable, Sendable {
    case startSession
    case enterTeachMode
    case returnToWork
    case nextStep
    case repeatHint
    case differentWay
    case askQuestion
    case checkWork
    case confirmHearing
    case connectAirPlay
    case displayOnScreen
    case markCorrected
    case endSession
    case pauseSession
    case resumeSession
    case emergencyStop
    case confirmUnderstood
    case ignore(String)

    var displayName: String {
        switch self {
        case .startSession: "Start session"
        case .enterTeachMode: "Enter Teach Mode"
        case .returnToWork: "Return to Observe Mode"
        case .nextStep: "Next math step"
        case .repeatHint: "Repeat hint"
        case .differentWay: "Different way"
        case .askQuestion: "Ask question"
        case .checkWork: "Check work"
        case .confirmHearing: "Confirm hearing"
        case .connectAirPlay: "Connect AirPlay"
        case .displayOnScreen: "Display on screen"
        case .markCorrected: "Mark corrected"
        case .endSession: "End session"
        case .pauseSession: "Pause session"
        case .resumeSession: "Resume session"
        case .emergencyStop: "Emergency stop"
        case .confirmUnderstood: "Confirm understood"
        case .ignore(let reason): "Ignored: \(reason)"
        }
    }
}

struct VoiceCommandRouter: Sendable {
    func route(_ command: VoiceCommand, in context: VoiceRouteContext) -> VoiceRoutedAction {
        if command == .emergencyStop, context.holderControlsActive {
            return .emergencyStop
        }

        switch command {
        case .startSession:
            switch context.location {
            case .studentPicker, .consent:
                return .startSession
            default:
                return .ignore("start is only valid before a session")
            }

        case .enterTeachMode:
            guard context.location == .liveSession else {
                return .ignore("teach mode requires a live session")
            }
            return context.canEnterTeachMode ? .enterTeachMode : .ignore("teach mode is cooling down")

        case .returnToWork:
            switch context.location {
            case .teachMode, .liveSession:
                return .returnToWork
            default:
                return .ignore("return to work requires an active session")
            }

        case .nextStep:
            return context.location == .teachMode ? .nextStep : .ignore("next step is only valid in Teach Mode")

        case .repeatHint:
            switch context.location {
            case .liveSession, .teachMode:
                return .repeatHint
            default:
                return .ignore("repeat requires an active session")
            }

        case .differentWay:
            switch context.location {
            case .liveSession, .teachMode:
                return .differentWay
            default:
                return .ignore("different way requires an active session")
            }

        case .askQuestion:
            switch context.location {
            case .liveSession, .teachMode:
                return .askQuestion
            default:
                return .ignore("question requires an active session")
            }

        case .checkWork:
            guard context.location == .liveSession else {
                return .ignore("check work requires a live session")
            }
            guard context.sessionStatus != .thinking else {
                return .ignore("check work is already running")
            }
            return .checkWork

        case .hearingTest:
            switch context.location {
            case .liveSession, .teachMode:
                return .confirmHearing
            default:
                return .ignore("hearing test requires an active session")
            }

        case .connectAirPlay:
            switch context.location {
            case .liveSession, .teachMode:
                return .connectAirPlay
            default:
                return .ignore("AirPlay requires an active session")
            }

        case .displayOnScreen:
            switch context.location {
            case .liveSession, .teachMode:
                return .displayOnScreen
            default:
                return .ignore("display requires an active session")
            }

        case .markCorrected:
            return context.location == .liveSession
                ? .markCorrected
                : .ignore("correction requires a live session")

        case .endSession:
            switch context.location {
            case .liveSession, .teachMode:
                return .endSession
            default:
                return .ignore("end requires an active session")
            }

        case .pause:
            switch context.location {
            case .liveSession, .teachMode:
                return .pauseSession
            default:
                return .ignore("pause requires an active session")
            }

        case .resume:
            guard context.sessionStatus == .paused else {
                return .ignore("resume requires a paused session")
            }
            return .resumeSession

        case .confirmUnderstood:
            return context.location == .teachMode ? .confirmUnderstood : .ignore("understood is only routed from Teach Mode")

        case .emergencyStop:
            return .ignore("holder controls are not active")

        case .unknown:
            return .ignore("unknown command")
        }
    }
}
