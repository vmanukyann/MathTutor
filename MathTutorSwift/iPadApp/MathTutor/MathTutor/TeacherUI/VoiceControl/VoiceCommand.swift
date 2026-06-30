import Foundation

enum VoiceCommand: String, CaseIterable, Identifiable, Sendable {
    case startSession
    case returnToWork
    case enterTeachMode
    case nextStep
    case repeatHint
    case differentWay
    case askQuestion
    case checkWork
    case connectAirPlay
    case displayOnScreen
    case markCorrected
    case endSession
    case pause
    case resume
    case emergencyStop
    case confirmUnderstood
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startSession: "Start session"
        case .returnToWork: "Return to work"
        case .enterTeachMode: "Teach mode"
        case .nextStep: "Next step"
        case .repeatHint: "Repeat"
        case .differentWay: "Different way"
        case .askQuestion: "Question"
        case .checkWork: "Check work"
        case .connectAirPlay: "Connect AirPlay"
        case .displayOnScreen: "Display on screen"
        case .markCorrected: "Mark corrected"
        case .endSession: "End session"
        case .pause: "Pause"
        case .resume: "Resume"
        case .emergencyStop: "Emergency stop"
        case .confirmUnderstood: "Understood"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .startSession: "arrow.right"
        case .returnToWork: "return"
        case .enterTeachMode: "rectangle.inset.filled.and.person.filled"
        case .nextStep: "arrow.right.to.line"
        case .repeatHint: "speaker.wave.2"
        case .differentWay: "arrow.triangle.2.circlepath"
        case .askQuestion: "questionmark"
        case .checkWork: "viewfinder"
        case .connectAirPlay: "airplayvideo"
        case .displayOnScreen: "rectangle.on.rectangle"
        case .markCorrected: "checkmark.circle"
        case .endSession: "xmark"
        case .pause: "pause.fill"
        case .resume: "play.fill"
        case .emergencyStop: "stop.fill"
        case .confirmUnderstood: "checkmark"
        case .unknown: "mic"
        }
    }
}

struct VoiceCommandMatch: Equatable, Sendable {
    var command: VoiceCommand
    var phrase: String
    var confidence: Double?

    static let none = VoiceCommandMatch(command: .unknown, phrase: "", confidence: nil)
}

enum VoiceCommandParser {
    static func parse(_ transcript: String, confidence: Double? = nil) -> VoiceCommandMatch? {
        let normalized = normalize(transcript)
        guard !normalized.isEmpty else { return nil }

        let command: VoiceCommand
        if normalized == "stop listening" {
            command = .pause
        } else if containsAny(normalized, emergencyStopPhrases) {
            command = .emergencyStop
        } else if containsAny(normalized, checkWorkPhrases) {
            command = .checkWork
        } else if containsAny(normalized, displayPhrases) {
            command = .displayOnScreen
        } else if containsAny(normalized, airPlayPhrases) {
            command = .connectAirPlay
        } else if containsAny(normalized, correctionPhrases) {
            command = .markCorrected
        } else if containsAny(normalized, endSessionPhrases) {
            command = .endSession
        } else if containsAny(normalized, startPhrases) {
            command = .startSession
        } else if containsAny(normalized, returnPhrases) {
            command = .returnToWork
        } else if containsAny(normalized, teachPhrases) {
            command = .enterTeachMode
        } else if containsAny(normalized, questionPhrases) {
            command = .askQuestion
        } else if containsAny(normalized, nextPhrases) {
            command = .nextStep
        } else if containsAny(normalized, repeatPhrases) {
            command = .repeatHint
        } else if containsAny(normalized, differentWayPhrases) {
            command = .differentWay
        } else if containsAny(normalized, pausePhrases) {
            command = .pause
        } else if containsAny(normalized, resumePhrases) {
            command = .resume
        } else if containsAny(normalized, confirmationPhrases) {
            command = .confirmUnderstood
        } else {
            return nil
        }

        return VoiceCommandMatch(command: command, phrase: transcript, confidence: confidence)
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ normalized: String, _ phrases: [String]) -> Bool {
        phrases.contains { phrase in
            normalized == phrase || normalized.contains(" \(phrase)") || normalized.contains("\(phrase) ")
        }
    }

    private static let startPhrases = [
        "start",
        "start session",
        "begin",
        "begin tutoring"
    ]

    private static let returnPhrases = [
        "back to work",
        "return to work",
        "go back",
        "keep watching",
        "observe",
        "watch my work"
    ]

    private static let teachPhrases = [
        "show me",
        "show me how",
        "show me how to do this",
        "can you show me",
        "can you show me how",
        "can you show me how to do this",
        "how do i do this",
        "help me do this",
        "help me",
        "flip",
        "flip the ipad",
        "show the step",
        "teach me",
        "im stuck",
        "i am stuck"
    ]

    private static let nextPhrases = [
        "next",
        "next step"
    ]

    private static let repeatPhrases = [
        "again",
        "repeat",
        "repeat this",
        "say that again",
        "repeat the hint",
        "explain again"
    ]

    private static let differentWayPhrases = [
        "slower",
        "different way",
        "another way",
        "explain differently"
    ]

    private static let questionPhrases = [
        "question",
        "i have a question",
        "can i ask something",
        "wait",
        "hold on"
    ]

    private static let checkWorkPhrases = [
        "check my work",
        "can you check my work",
        "check my work out",
        "can you check my work out",
        "see if there are any incorrect",
        "see if anything is incorrect",
        "are there any incorrect steps",
        "are there any mistakes",
        "is anything wrong",
        "check this",
        "look at my work",
        "did i do this right",
        "am i right",
        "scan my work",
        "check the problem"
    ]

    private static let airPlayPhrases = [
        "connect to airplay",
        "connect to the tv",
        "connect to bravia tv",
        "use airplay"
    ]

    private static let displayPhrases = [
        "display this on the screen",
        "display this on screen",
        "display this on the tv",
        "show this on the screen",
        "show this on screen",
        "show this on the tv",
        "put this on the screen",
        "put this on the tv",
        "show on the tv",
        "put it on the tv"
    ]

    private static let correctionPhrases = [
        "mark fixed",
        "i fixed it",
        "i corrected it",
        "that is fixed",
        "mark corrected"
    ]

    private static let endSessionPhrases = [
        "end session",
        "end the session",
        "finish session",
        "finish the session",
        "im done",
        "i am done"
    ]

    private static let pausePhrases = [
        "pause",
        "stop listening"
    ]

    private static let resumePhrases = [
        "resume",
        "keep going"
    ]

    private static let emergencyStopPhrases = [
        "stop",
        "emergency stop",
        "freeze",
        "stop moving"
    ]

    private static let confirmationPhrases = [
        "i understand",
        "got it",
        "that makes sense",
        "continue"
    ]
}
