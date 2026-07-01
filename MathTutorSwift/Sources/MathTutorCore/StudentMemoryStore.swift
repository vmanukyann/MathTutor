import Foundation

public protocol StudentMemoryStoring: Sendable {
    func loadStudents() throws -> [StudentProfile]
    func saveStudents(_ students: [StudentProfile]) throws
    func loadSessions() throws -> [TutoringSession]
    func saveSession(_ session: TutoringSession) throws
    func saveSessions(_ sessions: [TutoringSession]) throws
}

public final class FileStudentMemoryStore: StudentMemoryStoring, @unchecked Sendable {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadStudents() throws -> [StudentProfile] {
        let url = directory.appendingPathComponent("students.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [
                StudentProfile(
                    name: "Demo Student",
                    mathLevel: .algebraTwo,
                    consentAccepted: true,
                    misconceptionCounts: [.signError: 2, .distribution: 1]
                )
            ]
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([StudentProfile].self, from: data)
    }

    public func saveStudents(_ students: [StudentProfile]) throws {
        try ensureDirectory()
        let url = directory.appendingPathComponent("students.json")
        let data = try encoder.encode(students)
        try data.write(to: url, options: [.atomic])
    }

    public func loadSessions() throws -> [TutoringSession] {
        let url = directory.appendingPathComponent("sessions.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        return try decoder.decode([TutoringSession].self, from: data)
    }

    public func saveSession(_ session: TutoringSession) throws {
        try ensureDirectory()
        var sessions = try loadSessions()
        sessions.insert(session, at: 0)
        let url = directory.appendingPathComponent("sessions.json")
        let data = try encoder.encode(Array(sessions.prefix(100)))
        try data.write(to: url, options: [.atomic])
    }

    public func saveSessions(_ sessions: [TutoringSession]) throws {
        try ensureDirectory()
        let url = directory.appendingPathComponent("sessions.json")
        let data = try encoder.encode(Array(sessions.prefix(100)))
        try data.write(to: url, options: [.atomic])
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}
