import Foundation

struct ElevenLabsVoiceSettings: Encodable, Sendable {
    var stability: Double?
    var similarityBoost: Double?
    var style: Double?
    var useSpeakerBoost: Bool?

    init(
        stability: Double? = nil,
        similarityBoost: Double? = nil,
        style: Double? = nil,
        useSpeakerBoost: Bool? = nil
    ) {
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.useSpeakerBoost = useSpeakerBoost
    }
}

final class ElevenLabsTTSClient: VoiceTutorProvider, @unchecked Sendable {
    private let configuration: SupabaseConfiguration
    private let voiceID: String?
    private let modelID: String?
    private let voiceSettings: ElevenLabsVoiceSettings?
    private let urlSession: URLSession
    private let encoder: JSONEncoder

    init(
        configuration: SupabaseConfiguration,
        voiceID: String? = nil,
        modelID: String? = nil,
        voiceSettings: ElevenLabsVoiceSettings? = nil,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.voiceID = voiceID
        self.modelID = modelID
        self.voiceSettings = voiceSettings
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func audio(for text: String, requestID: String) async throws -> Data {
        let normalizedText = MathSpeechNormalizer.normalize(text)
        guard !normalizedText.isEmpty else {
            throw ElevenLabsTTSClientError.emptyText
        }

        let endpoint = configuration.url
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("tts-elevenlabs")
        let body = ElevenLabsTTSRequest(
            text: normalizedText,
            voiceID: voiceID,
            modelID: modelID,
            voiceSettings: voiceSettings
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(
            "Bearer \(configuration.anonKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID, forHTTPHeaderField: "X-MathTutor-Request-ID")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsTTSClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsTTSClientError.edgeFunctionFailed(
                status: httpResponse.statusCode,
                message: message
            )
        }
        guard !data.isEmpty else {
            throw ElevenLabsTTSClientError.emptyAudio
        }
        return data
    }
}

private struct ElevenLabsTTSRequest: Encodable {
    var text: String
    var voiceID: String?
    var modelID: String?
    var voiceSettings: ElevenLabsVoiceSettings?
}

private enum ElevenLabsTTSClientError: LocalizedError {
    case emptyText
    case invalidResponse
    case edgeFunctionFailed(status: Int, message: String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "There is no text to speak."
        case .invalidResponse:
            "The TTS function returned an invalid response."
        case let .edgeFunctionFailed(status, message):
            "The TTS function failed (\(status)): \(message)"
        case .emptyAudio:
            "The TTS function returned no audio."
        }
    }
}
