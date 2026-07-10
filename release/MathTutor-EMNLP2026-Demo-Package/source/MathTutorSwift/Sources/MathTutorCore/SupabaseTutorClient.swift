import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SupabaseConfiguration: Sendable {
    public var url: URL
    public var anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}

public struct TutorObservationRequest: Encodable, Sendable {
    public var imageBase64: String
    public var student: StudentProfile
    public var checkNumber: Int
    public var noAnswerMode: Bool
    public var studentQuestion: String?
    public var requestID: String?

    public init(
        imageBase64: String,
        student: StudentProfile,
        checkNumber: Int,
        noAnswerMode: Bool,
        studentQuestion: String? = nil,
        requestID: String? = nil
    ) {
        self.imageBase64 = imageBase64
        self.student = student
        self.checkNumber = checkNumber
        self.noAnswerMode = noAnswerMode
        self.studentQuestion = studentQuestion
        self.requestID = requestID
    }
}

public protocol TutorBrainServicing: Sendable {
    func observeWork(_ request: TutorObservationRequest) async throws -> TutorObservation
    func logSession(_ session: TutoringSession) async throws
}

public final class SupabaseTutorClient: TutorBrainServicing, @unchecked Sendable {
    private let configuration: SupabaseConfiguration
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: SupabaseConfiguration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    public func observeWork(_ request: TutorObservationRequest) async throws -> TutorObservation {
        let trace = TutorClientLatencyTrace(
            scope: "observe_work",
            id: request.requestID ?? UUID().uuidString
        )
        trace.log("tutor_request_started", fields: ["check": "\(request.checkNumber)"])
        let endpoint = configuration.url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("tutor")

        let body = EdgeObservationRequest(
            mode: "observe_work",
            imageBase64: request.imageBase64,
            student: EdgeStudentContext(
                id: request.student.id.uuidString,
                name: request.student.name,
                level: request.student.mathLevel.displayName,
                misconceptions: request.student.misconceptionCounts
                    .reduce(into: [String: Int]()) { partial, row in
                        partial[row.key.rawValue] = row.value
                    }
            ),
            session: EdgeSessionContext(
                checkNumber: request.checkNumber,
                noAnswerMode: request.noAnswerMode,
                studentQuestion: request.studentQuestion
            )
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(trace.id, forHTTPHeaderField: "X-MathTutor-Request-ID")
        urlRequest.httpBody = try encoder.encode(body)
        trace.log("tutor_request_body_prepared", fields: [
            "base64_bytes": "\(request.imageBase64.utf8.count)",
            "request_bytes": "\(urlRequest.httpBody?.count ?? 0)",
        ])

        let (data, response) = try await urlSession.data(for: urlRequest)
        trace.log("tutor_response_received", fields: ["bytes": "\(data.count)"])
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TutorClientError.edgeFunctionFailed(message)
        }

        let observation = try decoder.decode(TutorObservation.self, from: data)
        trace.log("tutor_response_decoded", fields: [
            "spoken_words": "\(observation.spokenHint.split(whereSeparator: { $0.isWhitespace }).count)",
        ])
        return observation
    }

    public func logSession(_ session: TutoringSession) async throws {
        let endpoint = configuration.url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("tutor")

        let body = EdgeSessionLogRequest(session: session)

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TutorClientError.edgeFunctionFailed(message)
        }
    }

}

private final class TutorClientLatencyTrace {
    private let clock = ContinuousClock()
    private let scope: String
    let id: String
    private let startedAt: ContinuousClock.Instant

    init(scope: String, id: String) {
        self.scope = scope
        self.id = id
        self.startedAt = clock.now
    }

    func log(_ event: String, fields: [String: String] = [:]) {
        let elapsed = startedAt.duration(to: clock.now)
        let milliseconds = elapsed.components.seconds * 1_000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
        let suffix = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let message = "mathtutor_elevenlabs_latency scope=\(scope) event=\(event) request_id=\(id) elapsed_ms=\(milliseconds)"
        print(suffix.isEmpty ? message : "\(message) \(suffix)")
    }
}

public enum TutorClientError: Error, LocalizedError, Sendable {
    case edgeFunctionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .edgeFunctionFailed(let message):
            return "Tutor Edge Function failed: \(message)"
        }
    }
}

private struct EdgeObservationRequest: Encodable {
    var mode: String
    var imageBase64: String
    var student: EdgeStudentContext
    var session: EdgeSessionContext
}

private struct EdgeStudentContext: Encodable {
    var id: String
    var name: String
    var level: String
    var misconceptions: [String: Int]
}

private struct EdgeSessionContext: Encodable {
    var checkNumber: Int
    var noAnswerMode: Bool
    var studentQuestion: String?
}

private struct EdgeSessionLogRequest: Encodable {
    var mode = "log_session"
    var student: EdgeLoggedStudent
    var session: EdgeLoggedSession
    var events: [EdgeLoggedEvent]

    init(session source: TutoringSession) {
        self.student = EdgeLoggedStudent(student: source.student)
        self.session = EdgeLoggedSession(session: source)
        self.events = source.events.map(EdgeLoggedEvent.init)
    }
}

private struct EdgeLoggedStudent: Encodable {
    var id: String
    var name: String
    var mathLevel: String
    var consentAccepted: Bool
    var misconceptionCounts: [String: Int]

    init(student: StudentProfile) {
        self.id = student.id.uuidString
        self.name = student.name
        self.mathLevel = student.mathLevel.displayName
        self.consentAccepted = student.consentAccepted
        self.misconceptionCounts = student.misconceptionCounts.reduce(
            into: [String: Int]()
        ) { partial, row in
            partial[row.key.rawValue] = row.value
        }
    }
}

private struct EdgeLoggedSession: Encodable {
    var id: String
    var startedAt: Date
    var endedAt: Date?
    var reflection: String

    init(session: TutoringSession) {
        self.id = session.id.uuidString
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.reflection = session.reflection
    }
}

private struct EdgeLoggedEvent: Encodable {
    var id: String
    var observedAt: Date
    var mistakeDetected: Bool
    var confidence: String
    var misconceptionType: String
    var hintLevel: Int
    var hint: String
    var teacherNote: String
    var workSummary: String
    var studentSelfCorrected: Bool
    var finalAnswerBlocked: Bool

    init(event: TutorEvent) {
        self.id = event.id.uuidString
        self.observedAt = event.timestamp
        self.mistakeDetected = event.observation.mistakeDetected
        self.confidence = event.observation.confidence.rawValue
        self.misconceptionType = event.observation.misconceptionType.rawValue
        self.hintLevel = event.observation.hintLevel
        self.hint = event.observation.hint
        self.teacherNote = event.observation.teacherNote
        self.workSummary = event.observation.workSummary
        self.studentSelfCorrected = event.studentSelfCorrected
        self.finalAnswerBlocked = event.observation.finalAnswerBlocked
    }
}
