import Foundation

public enum MathLevel: String, Codable, CaseIterable, Sendable {
    case algebraOne
    case algebraTwo
    case satMath
    case precalculus

    public var displayName: String {
        switch self {
        case .algebraOne: "Algebra I"
        case .algebraTwo: "Algebra II"
        case .satMath: "SAT Math"
        case .precalculus: "Precalculus"
        }
    }
}

public enum MisconceptionType: String, Codable, CaseIterable, Sendable {
    case signError = "sign_error"
    case distribution
    case equationBalance = "equation_balance"
    case invalidCancellation = "invalid_cancellation"
    case slopeIntercept = "slope_intercept"
    case factoring
    case satStrategy = "sat_strategy"
    case unclearWork = "unclear_work"

    public var displayName: String {
        switch self {
        case .signError: "Sign error"
        case .distribution: "Distribution"
        case .equationBalance: "Equation balance"
        case .invalidCancellation: "Invalid cancellation"
        case .slopeIntercept: "Slope/intercept"
        case .factoring: "Factoring"
        case .satStrategy: "SAT strategy"
        case .unclearWork: "Unclear work"
        }
    }
}

public struct StudentProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var mathLevel: MathLevel
    public var consentAccepted: Bool
    public var createdAt: Date
    public var misconceptionCounts: [MisconceptionType: Int]

    public init(
        id: UUID = UUID(),
        name: String,
        mathLevel: MathLevel,
        consentAccepted: Bool = false,
        createdAt: Date = Date(),
        misconceptionCounts: [MisconceptionType: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.mathLevel = mathLevel
        self.consentAccepted = consentAccepted
        self.createdAt = createdAt
        self.misconceptionCounts = misconceptionCounts
    }

    public var topMisconceptions: [MisconceptionType] {
        misconceptionCounts
            .sorted { $0.value > $1.value }
            .map(\.key)
    }

    public mutating func record(_ misconception: MisconceptionType) {
        misconceptionCounts[misconception, default: 0] += 1
    }
}
