import AVFoundation
import Combine

@MainActor
final class VoiceTutor: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let tutorClient: SupabaseTutorClient
    private var audioPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?
    private var currentUtterance: AVSpeechUtterance?
    private var currentSpokenText = ""

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?

    init(configuration: SupabaseConfiguration) {
        tutorClient = SupabaseTutorClient(configuration: configuration)
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let preparedText = spokenText(from: text)
        guard !preparedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard preparedText != currentSpokenText else { return }

        stop()
        currentSpokenText = preparedText

        speechTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await tutorClient.generateSpeech(preparedText)
                guard !Task.isCancelled, currentSpokenText == preparedText else { return }
                try playGeneratedAudio(data)
            } catch {
                // The lesson should still work if the network drops.
                guard !Task.isCancelled, currentSpokenText == preparedText else { return }
                speakWithSystemVoice(preparedText)
            }
        }
    }

    func stop() {
        speechTask?.cancel()
        speechTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        currentSpokenText = ""
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
        )
        try? audioSession.setActive(true)
        try? audioSession.overrideOutputAudioPort(.speaker)
    }

    private func playGeneratedAudio(_ data: Data) throws {
        configureAudioSession()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        audioPlayer = player
        onSpeechStarted?()
        player.play()
    }

    private func speakWithSystemVoice(_ preparedText: String) {
        configureAudioSession()
        let utterance = AVSpeechUtterance(string: preparedText)
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        currentUtterance = utterance
        onSpeechStarted?()
        synthesizer.speak(utterance)
    }

    private func spokenText(from source: String) -> String {
        // AVSpeechSynthesizer reads raw LaTeX pretty badly, so clean up the common cases.
        var text = source
        text = replacing(#"\\frac\{([^{}]+)\}\{([^{}]+)\}"#, in: text, with: "$1 divided by $2")
        text = replacing(#"([A-Za-z0-9]+)\^\{2\}"#, in: text, with: "$1 squared")
        text = replacing(#"([A-Za-z0-9]+)\^\{3\}"#, in: text, with: "$1 cubed")
        text = replacing(#"\\sqrt\{([^{}]+)\}"#, in: text, with: "the square root of $1")

        return text
            .replacingOccurrences(of: "\\(", with: "")
            .replacingOccurrences(of: "\\)", with: "")
            .replacingOccurrences(of: "\\[", with: "")
            .replacingOccurrences(of: "\\]", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "\\cdot", with: " times ")
            .replacingOccurrences(of: "\\times", with: " times ")
            .replacingOccurrences(of: "\\div", with: " divided by ")
            .replacingOccurrences(of: "\\neq", with: " is not equal to ")
            .replacingOccurrences(of: "\\leq", with: " is less than or equal to ")
            .replacingOccurrences(of: "\\geq", with: " is greater than or equal to ")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }

    private func replacing(_ pattern: String, in source: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        return regex.stringByReplacingMatches(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source),
            withTemplate: template
        )
    }
}

extension VoiceTutor: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self, player === audioPlayer else { return }
            audioPlayer = nil
            currentSpokenText = ""
            onSpeechFinished?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, utterance === currentUtterance else { return }
            currentUtterance = nil
            currentSpokenText = ""
            onSpeechFinished?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, utterance === currentUtterance else { return }
            currentUtterance = nil
            currentSpokenText = ""
            onSpeechFinished?()
        }
    }
}
