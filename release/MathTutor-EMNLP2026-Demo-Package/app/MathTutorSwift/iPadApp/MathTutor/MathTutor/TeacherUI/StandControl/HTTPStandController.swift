import Foundation

struct HTTPStandController: Sendable {
    var baseURL: URL
    var session: URLSession = .shared

    func send(_ command: StandCommand) async throws {
        let url = baseURL.appendingPathComponent(command.httpPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw StandControllerError.httpFailed
        }
    }
}

enum StandControllerError: LocalizedError {
    case invalidBaseURL
    case httpFailed

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "The stand URL is not valid."
        case .httpFailed:
            "The stand did not accept the command."
        }
    }
}
