import AVFoundation
import Combine
import FluidAudio

@MainActor
final class VoiceTutor: NSObject, ObservableObject {
    @Published private(set) var voiceStatus = "Downloading the voice model…"
    @Published private(set) var isReady = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?

    private let manager = PocketTtsManager(precision: .int8, placement: .gpu)
    private var clonedVoice: PocketTtsVoiceData?
    private var player: AVAudioPlayer?
    private var pendingText: String?
    private var currentSpokenText = ""
    private var synthesisTask: Task<Void, Never>?
    private var didBeginSpeech = false

    private let voiceSampleURL = URL(
        string: "https://zydgcutdgkgjvstzrafo.supabase.co/storage/v1/object/public/tts-assets/voice.wav"
    )!

    override init() {
        super.init()
        Task { [weak self] in
            await self?.prepareVoice()
        }
    }

    func speak(_ text: String) {
        let preparedText = spokenText(from: text)
        guard !preparedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard preparedText != currentSpokenText else { return }

        stop()
        currentSpokenText = preparedText

        guard isReady else {
            pendingText = preparedText
            return
        }
        synthesizeAndPlay(preparedText)
    }

    func stop() {
        let shouldNotify = didBeginSpeech
        didBeginSpeech = false
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
        pendingText = nil
        currentSpokenText = ""
        if isReady {
            voiceStatus = "Your voice is ready"
        }
        if shouldNotify {
            onSpeechFinished?()
        }
    }

    private func prepareVoice() async {
        do {
            voiceStatus = "Downloading the native voice model…"
            try await manager.initialize()

            voiceStatus = "Preparing your recorded voice…"
            let (temporaryURL, response) = try await URLSession.shared.download(from: voiceSampleURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let voiceData = try await manager.cloneVoice(from: temporaryURL)
            clonedVoice = voiceData
            voiceStatus = "Finishing voice preparation…"
            _ = try await manager.synthesize(
                text: "Let’s look at step two together. Check the operation, then try the next step.",
                voiceData: voiceData
            )

            isReady = true
            voiceStatus = "Your voice is ready"

            if let pendingText {
                self.pendingText = nil
                synthesizeAndPlay(pendingText)
            }
        } catch {
            voiceStatus = "Voice loading failed: \(error.localizedDescription)"
        }
    }

    private func synthesizeAndPlay(_ text: String) {
        guard let clonedVoice else { return }
        voiceStatus = "Creating speech…"

        synthesisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audio = try await manager.synthesize(
                    text: text,
                    voiceData: clonedVoice
                )
                try Task.checkCancellation()

                let player = try AVAudioPlayer(data: audio)
                self.player = player
                player.delegate = self

                didBeginSpeech = true
                onSpeechStarted?()
                configureAudioSession()
                try await Task.sleep(for: .milliseconds(200))
                try Task.checkCancellation()
                guard self.player === player else { throw CancellationError() }

                player.prepareToPlay()
                voiceStatus = "Speaking…"
                guard player.play() else {
                    throw VoiceTutorError.playbackDidNotStart
                }
            } catch is CancellationError {
                return
            } catch {
                finishSpeaking()
                voiceStatus = "Speech failed: \(error.localizedDescription)"
            }
        }
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? audioSession.setActive(true)
    }

    private func spokenText(from source: String) -> String {
        source
            .replacingOccurrences(
                of: #"\\\(.*?\\\)|\\\[.*?\\\]|\$\$?.*?\$\$?"#,
                with: "the marked expression",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\\[A-Za-z]+"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finishSpeaking() {
        let shouldNotify = didBeginSpeech
        didBeginSpeech = false
        player?.stop()
        player = nil
        synthesisTask = nil
        currentSpokenText = ""
        voiceStatus = "Your voice is ready"
        if shouldNotify {
            onSpeechFinished?()
        }
    }
}

private enum VoiceTutorError: LocalizedError {
    case playbackDidNotStart

    var errorDescription: String? {
        "Audio playback did not start."
    }
}

extension VoiceTutor: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self, player === self.player else { return }
            finishSpeaking()
        }
    }
}
