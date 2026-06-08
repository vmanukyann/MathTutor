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
    case paused
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
    public var teacherNote: String
    public var workSummary: String
    public var finalAnswerBlocked: Bool

    public init(
        mistakeDetected: Bool,
        confidence: TutorConfidence,
        misconceptionType: MisconceptionType,
        hintLevel: Int,
        hint: String,
        teacherNote: String,
        workSummary: String,
        finalAnswerBlocked: Bool = true
    ) {
        self.mistakeDetected = mistakeDetected
        self.confidence = confidence
        self.misconceptionType = misconceptionType
        self.hintLevel = min(4, max(1, hintLevel))
        self.hint = hint
        self.teacherNote = teacherNote
        self.workSummary = workSummary
        self.finalAnswerBlocked = finalAnswerBlocked
    }
}

public struct TutorEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var observation: TutorObservation
    public var studentSelfCorrected: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        observation: TutorObservation,
        studentSelfCorrected: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.observation = observation
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
