import Foundation
import Speech

enum VoiceControlMode: String, Sendable {
    case idle
    case listening
    case processing
    case askingQuestion
    case disabled

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening"
        case .processing: "Processing"
        case .askingQuestion: "Question"
        case .disabled: "Disabled"
        }
    }
}

enum VoicePermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    var displayName: String {
        switch self {
        case .notDetermined: "Not determined"
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }

    init(speechStatus: SFSpeechRecognizerAuthorizationStatus) {
        switch speechStatus {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .unavailable
        }
    }
}

struct VoiceControlSnapshot: Equatable, Sendable {
    var isListening = false
    var isAvailable = false
    var isMicrophoneAuthorized = false
    var permissionStatus: VoicePermissionStatus = .notDetermined
    var lastTranscript = ""
    var lastRecognizedCommand: VoiceCommand?
    var lastError: String?
    var confidence: Double?
    var currentVoiceMode: VoiceControlMode = .idle
    var routedAction = ""
}
