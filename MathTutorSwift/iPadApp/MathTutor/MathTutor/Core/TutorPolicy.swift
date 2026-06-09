import Foundation

public struct TutorPolicy: Sendable {
    public var noAnswerMode: Bool
    public var minimumConfidenceToInterrupt: TutorConfidence

    public init(
        noAnswerMode: Bool = true,
        minimumConfidenceToInterrupt: TutorConfidence = .medium
    ) {
        self.noAnswerMode = noAnswerMode
        self.minimumConfidenceToInterrupt = minimumConfidenceToInterrupt
    }

    public func shouldInterrupt(for observation: TutorObservation) -> Bool {
        if observation.mistakeDetected == false {
            return false
        }

        switch (minimumConfidenceToInterrupt, observation.confidence) {
        case (.low, _):
            return true
        case (.medium, .medium), (.medium, .high):
            return true
        case (.high, .high):
            return true
        default:
            return false
        }
    }

    public func sanitizedHint(_ hint: String) -> String {
        guard noAnswerMode else { return hint }

        let blockedPhrases = [
            "the answer is",
            "final answer",
            "equals x",
            "x =",
            "y ="
        ]

        let lowercased = hint.lowercased()
        if blockedPhrases.contains(where: lowercased.contains) {
            return "I can guide you, but I will not give the final answer. Compare this step to the previous one and explain what changed."
        }

        return hint
    }

    public func personalizedOpening(
        student: StudentProfile,
        misconception: MisconceptionType
    ) -> String {
        let count = student.misconceptionCounts[misconception, default: 0]
        guard count > 0 else { return student.name }

        return "\(student.name), this resembles a \(misconception.displayName.lowercased()) pattern you have worked on before"
    }
}
