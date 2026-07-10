import Foundation

public enum TutorConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum SessionStatus: String, Codable, Sendable {
    case watching
    case thinking
    case hintReady
}

public struct MathWorkState: Codable, Equatable, Sendable {
    public var topic: String
    public var recognizedSteps: [String]
    public var latestSummary: String
    public var confidence: TutorConfidence

    public init(
        topic: String = "Unknown",
        recognizedSteps: [String] = [],
        latestSummary: String = "",
        confidence: TutorConfidence = .low
    ) {
        self.topic = topic
        self.recognizedSteps = recognizedSteps
        self.latestSummary = latestSummary
        self.confidence = confidence
    }
}

public struct TutorObservation: Codable, Equatable, Sendable {
    public var mistakeDetected: Bool
    public var confidence: TutorConfidence
    public var misconceptionType: MisconceptionType
    public var hintLevel: Int
    public var hint: String
    public var spokenHint: String
    public var hintExplanation: String?
    public var hintAction: String?
    public var displayHint: String?
    public var tryStep: String?
    public var teacherNote: String
    public var workSummary: String
    public var teachSteps: [String]?
    public var finalAnswerBlocked: Bool
    public var visionDetail: String?
    public var observeMaxOutputTokens: Int?
    public var promptCharacters: Int?
    public var responseBytes: Int?

    public init(
        mistakeDetected: Bool,
        confidence: TutorConfidence,
        misconceptionType: MisconceptionType,
        hintLevel: Int,
        hint: String,
        spokenHint: String = "",
        hintExplanation: String? = nil,
        hintAction: String? = nil,
        displayHint: String? = nil,
        tryStep: String? = nil,
        teacherNote: String,
        workSummary: String,
        teachSteps: [String]? = nil,
        finalAnswerBlocked: Bool = true,
        visionDetail: String? = nil,
        observeMaxOutputTokens: Int? = nil,
        promptCharacters: Int? = nil,
        responseBytes: Int? = nil
    ) {
        self.mistakeDetected = mistakeDetected
        self.confidence = confidence
        self.misconceptionType = misconceptionType
        self.hintLevel = min(3, max(1, hintLevel))
        self.hint = hint
        self.spokenHint = spokenHint
        self.hintExplanation = hintExplanation
        self.hintAction = hintAction
        self.displayHint = displayHint
        self.tryStep = tryStep
        self.teacherNote = teacherNote
        self.workSummary = workSummary
        self.teachSteps = teachSteps
        self.finalAnswerBlocked = finalAnswerBlocked
        self.visionDetail = visionDetail
        self.observeMaxOutputTokens = observeMaxOutputTokens
        self.promptCharacters = promptCharacters
        self.responseBytes = responseBytes
    }
}

public struct TutorEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var observation: TutorObservation
    public var tutorMessage: String?
    public var studentSelfCorrected: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        observation: TutorObservation,
        tutorMessage: String? = nil,
        studentSelfCorrected: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.observation = observation
        self.tutorMessage = tutorMessage
        self.studentSelfCorrected = studentSelfCorrected
    }
}

public struct TutoringSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var student: StudentProfile
    public var startedAt: Date
    public var endedAt: Date?
    public var events: [TutorEvent]
    public var reflection: String

    public init(
        id: UUID = UUID(),
        student: StudentProfile,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        events: [TutorEvent] = [],
        reflection: String = ""
    ) {
        self.id = id
        self.student = student
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.events = events
        self.reflection = reflection
    }

    public var mistakeCount: Int {
        events.filter(\.observation.mistakeDetected).count
    }

    public var selfCorrectionCount: Int {
        events.filter(\.studentSelfCorrected).count
    }
}
