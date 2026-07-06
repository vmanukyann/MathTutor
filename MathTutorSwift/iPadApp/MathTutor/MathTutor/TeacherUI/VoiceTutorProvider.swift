import Foundation

protocol VoiceTutorProvider: Sendable {
    func audio(for text: String, requestID: String) async throws -> Data
}
