import AVFoundation
import Combine

struct TutorSpeechLatencyContext {
    let userActionStarted: ContinuousClock.Instant
    let tutorRequestStarted: ContinuousClock.Instant
    let tutorResponseReceived: ContinuousClock.Instant
    let imagePreset: String
    let imageBytes: Int
    let visionDetail: String
    let usedCachedFrame: Bool
    let cachedFrameAgeMilliseconds: Int
    let captureTimeMilliseconds: Int64
    let observeMaxOutputTokens: Int
    let promptCharacters: Int
    let responseBytes: Int
}

@MainActor
final class VoiceTutor: NSObject, ObservableObject {
    @Published private(set) var voiceStatus = "Your voice is ready"
    @Published private(set) var isReady = true

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?

    private let provider: any VoiceTutorProvider
    private let usesPocketLatencyLogs: Bool
    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?
    private var currentSpokenText = ""
    private var didBeginSpeech = false
    private var playbackID = UUID()
    private var latencyTrace: VoiceLatencyTrace?
    private var currentPlaybackUsesPocketLatencyLogs = false

    override init() {
        let providerSelection = VoiceTutorProviderFactory.makeProvider()
        self.provider = providerSelection.provider
        self.usesPocketLatencyLogs = providerSelection.usesPocketLatencyLogs
        super.init()
        removeObsoleteLocalVoiceCache()
    }

    init(provider: any VoiceTutorProvider) {
        self.provider = provider
        self.usesPocketLatencyLogs = VoiceTutorProviderFactory.isPocketProvider(provider)
        super.init()
        removeObsoleteLocalVoiceCache()
    }

    func speak(
        _ text: String,
        requestID: String? = nil,
        latencyContext: TutorSpeechLatencyContext? = nil
    ) {
        let preparedText = spokenText(from: text)
        guard !preparedText.isEmpty, preparedText != currentSpokenText else {
            return
        }

        stop()
        currentSpokenText = preparedText
        voiceStatus = "Creating speech…"

        let activePlaybackID = UUID()
        playbackID = activePlaybackID
        currentPlaybackUsesPocketLatencyLogs = usesPocketLatencyLogs
        let trace = VoiceLatencyTrace(id: requestID ?? UUID().uuidString)
        latencyTrace = trace
        if currentPlaybackUsesPocketLatencyLogs {
            trace.logPocket("tts_request_started", fields: [
                "words": "\(wordCount(preparedText))",
            ])
        } else {
            trace.log("tts_request_started", fields: [
                "words": "\(wordCount(preparedText))",
            ])
        }

        synthesisTask = Task { [weak self, provider] in
            do {
                let audio = try await provider.audio(
                    for: preparedText,
                    requestID: trace.id
                )
                try Task.checkCancellation()
                guard let self, self.playbackID == activePlaybackID else {
                    throw CancellationError()
                }

                let audioReceivedAt = ContinuousClock().now
                if self.currentPlaybackUsesPocketLatencyLogs {
                    trace.logPocket("ipad_received_tts_response", fields: [
                        "bytes": "\(audio.count)",
                    ])
                } else {
                    trace.log("ipad_received_tts_response", fields: [
                        "bytes": "\(audio.count)",
                    ])
                }
                try self.startPlayback(
                    audio,
                    playbackID: activePlaybackID,
                    trace: trace,
                    latencyContext: latencyContext,
                    audioReceivedAt: audioReceivedAt
                )
            } catch is CancellationError {
                if self?.currentPlaybackUsesPocketLatencyLogs == true {
                    trace.logPocket("tts_request_cancelled")
                } else {
                    trace.log("tts_request_cancelled")
                }
            } catch {
                guard let self, self.playbackID == activePlaybackID else {
                    return
                }
                self.synthesisTask = nil
                self.currentSpokenText = ""
                self.voiceStatus = "Speech failed: \(error.localizedDescription)"
                if self.currentPlaybackUsesPocketLatencyLogs {
                    trace.logPocket("tts_request_failed", fields: [
                        "error": error.localizedDescription,
                    ])
                } else {
                    trace.log("tts_request_failed", fields: [
                        "error": error.localizedDescription,
                    ])
                }
            }
        }
    }

    func stop() {
        let shouldNotify = didBeginSpeech
        playbackID = UUID()
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
        currentSpokenText = ""
        didBeginSpeech = false
        voiceStatus = "Your voice is ready"
        if shouldNotify {
            if currentPlaybackUsesPocketLatencyLogs {
                latencyTrace?.logPocket("playback_finished", fields: [
                    "reason": "interrupted",
                ])
            } else {
                latencyTrace?.log("playback_finished", fields: [
                    "reason": "interrupted",
                ])
            }
            onSpeechFinished?()
        }
        currentPlaybackUsesPocketLatencyLogs = false
    }

    private func startPlayback(
        _ audio: Data,
        playbackID: UUID,
        trace: VoiceLatencyTrace,
        latencyContext: TutorSpeechLatencyContext?,
        audioReceivedAt: ContinuousClock.Instant
    ) throws {
        configureAudioSession()
        let player = try AVAudioPlayer(data: audio)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        if currentPlaybackUsesPocketLatencyLogs {
            trace.logPocket("playback_prepared")
        } else {
            trace.log("audio_playback_prepared")
        }

        guard self.playbackID == playbackID, player.play() else {
            self.player = nil
            throw VoiceTutorError.playbackDidNotStart
        }

        synthesisTask = nil
        didBeginSpeech = true
        voiceStatus = "Speaking…"
        if currentPlaybackUsesPocketLatencyLogs {
            trace.logPocket("playback_started")
            print("mathtutor_pockettts_latency playback_started=true request_id=\(trace.id)")
            trace.logPocket("total_time_to_first_audio")
        } else {
            trace.log("playback_started")
        }
        if let latencyContext {
            trace.logSummary(
                context: latencyContext,
                audioReceivedAt: audioReceivedAt,
                playbackStartedAt: ContinuousClock().now
            )
        }
        onSpeechStarted?()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
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

    private func wordCount(_ source: String) -> Int {
        source.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func removeObsoleteLocalVoiceCache() {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        let obsoleteCache = applicationSupport
            .appendingPathComponent("MathTutor", isDirectory: true)
            .appendingPathComponent("voice_prompt.bin")
        try? FileManager.default.removeItem(at: obsoleteCache)
    }
}

extension VoiceTutor: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self, player === self.player else { return }
            self.player = nil
            self.didBeginSpeech = false
            let shouldLogPocket = self.currentPlaybackUsesPocketLatencyLogs
            self.currentPlaybackUsesPocketLatencyLogs = false
            self.currentSpokenText = ""
            self.voiceStatus = "Your voice is ready"
            if shouldLogPocket {
                self.latencyTrace?.logPocket("playback_finished", fields: [
                    "success": "\(flag)",
                ])
            } else {
                self.latencyTrace?.log("playback_finished", fields: [
                    "success": "\(flag)",
                ])
            }
            self.onSpeechFinished?()
        }
    }
}

private enum VoiceTutorError: LocalizedError {
    case playbackDidNotStart

    var errorDescription: String? {
        "Audio playback did not start."
    }
}

private final class VoiceLatencyTrace {
    private let clock = ContinuousClock()
    let id: String
    private let startedAt: ContinuousClock.Instant

    init(id: String) {
        self.id = id
        self.startedAt = clock.now
    }

    func log(_ event: String, fields: [String: String] = [:]) {
        log(prefix: "mathtutor_elevenlabs_latency", event: event, fields: fields)
    }

    func logPocket(_ event: String, fields: [String: String] = [:]) {
        log(prefix: "mathtutor_pockettts_latency", event: event, fields: fields)
    }

    private func log(prefix: String, event: String, fields: [String: String]) {
        let elapsed = startedAt.duration(to: clock.now)
        let milliseconds = elapsed.components.seconds * 1_000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
        let suffix = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let message = "\(prefix) event=\(event) request_id=\(id) elapsed_ms=\(milliseconds)"
        print(suffix.isEmpty ? message : "\(message) \(suffix)")
    }

    func logSummary(
        context: TutorSpeechLatencyContext,
        audioReceivedAt: ContinuousClock.Instant,
        playbackStartedAt: ContinuousClock.Instant
    ) {
        log("full_path_timing_summary", fields: [
            "cached_frame_age_ms": "\(context.cachedFrameAgeMilliseconds)",
            "capture_time_ms": "\(context.captureTimeMilliseconds)",
            "image_bytes": "\(context.imageBytes)",
            "image_preset": context.imagePreset,
            "observe_max_output_tokens": "\(context.observeMaxOutputTokens)",
            "prompt_chars": "\(context.promptCharacters)",
            "response_bytes": "\(context.responseBytes)",
            "user_action_to_tutor_request_ms": milliseconds(
                from: context.userActionStarted,
                to: context.tutorRequestStarted
            ),
            "tutor_request_to_tutor_response_ms": milliseconds(
                from: context.tutorRequestStarted,
                to: context.tutorResponseReceived
            ),
            "tutor_response_to_tts_request_ms": milliseconds(
                from: context.tutorResponseReceived,
                to: startedAt
            ),
            "tts_request_to_ipad_audio_ms": milliseconds(
                from: startedAt,
                to: audioReceivedAt
            ),
            "ipad_audio_to_playback_ms": milliseconds(
                from: audioReceivedAt,
                to: playbackStartedAt
            ),
            "total_user_action_to_playback_ms": milliseconds(
                from: context.userActionStarted,
                to: playbackStartedAt
            ),
            "vision_detail": context.visionDetail,
            "used_cached_frame": "\(context.usedCachedFrame)",
        ])
    }

    private func milliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> String {
        let duration = start.duration(to: end)
        let value = duration.components.seconds * 1_000
            + duration.components.attoseconds / 1_000_000_000_000_000
        return "\(value)"
    }
}

#if DEBUG
extension VoiceTutor {
    static let diagnosticPhrase =
        "sixteen, seventeen, eighteen, nineteen, twenty. Now divide both sides by sixteen."

    func runElevenLabsTtsDiagnostic() {
        speak(Self.diagnosticPhrase)
    }

    func runPocketTtsDiagnostic() {
        speak(
            Self.diagnosticPhrase,
            requestID: "pocket_tts_diagnostic"
        )
    }
}
#endif

private enum VoiceTutorProviderFactory {
    static func makeProvider(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> VoiceTutorProviderSelection {
        logStartupArguments(arguments)
        let parsed = TTSLaunchArguments(arguments: arguments)

        print("mathtutor_tts_provider pocket_diagnostic=\(parsed.pocketDiagnosticRequested)")
        print("mathtutor_tts_provider pocket_prewarm=false")
        print("mathtutor_tts_provider pocket_fallback=false")
        #if DEBUG
        if parsed.requestsPocketProvider {
            print("mathtutor_tts_provider selected=pocket")
            print("mathtutor_tts_provider reason=explicit_debug_launch_arg")
            print("mathtutor_tts_provider fallback=disabled")
            print("mathtutor_pockettts_latency event=provider_selected provider=pocket fallback=disabled")
            return VoiceTutorProviderSelection(
                provider: PocketTTSProvider.shared,
                usesPocketLatencyLogs: true
            )
        }
        #endif

        if parsed.requestsPocketProvider {
            print("mathtutor_tts_provider selected=elevenlabs reason=pocket_ignored_outside_debug")
        } else if parsed.requestedProvider == "elevenlabs" {
            print("mathtutor_tts_provider selected=elevenlabs reason=explicit_launch_arg")
        } else if let requestedProvider = parsed.requestedProvider {
            print("mathtutor_tts_provider selected=elevenlabs reason=unknown_tts_provider value=\(requestedProvider)")
        } else {
            print("mathtutor_tts_provider selected=elevenlabs reason=default")
        }
        print("mathtutor_elevenlabs_latency event=provider_selected provider=elevenlabs")
        let elevenLabs = ElevenLabsTTSClient(configuration: AppSecrets.supabase)
        return VoiceTutorProviderSelection(
            provider: elevenLabs,
            usesPocketLatencyLogs: false
        )
    }

    static func isPocketProvider(_ provider: any VoiceTutorProvider) -> Bool {
        #if DEBUG
        provider is PocketTTSProvider
        #else
        false
        #endif
    }

    nonisolated private static func logStartupArguments(_ arguments: [String]) {
        let sanitized = arguments
            .dropFirst()
            .map(sanitizedArgument)
            .joined(separator: ",")
        print("mathtutor_tts_provider available_args=[\(sanitized)]")
    }

    nonisolated private static func sanitizedArgument(_ argument: String) -> String {
        if argument.hasPrefix("--pocket-voice-prompt=") {
            return "--pocket-voice-prompt=<path>"
        }
        if argument.lowercased().contains("key=")
            || argument.lowercased().contains("token=")
            || argument.lowercased().contains("secret=") {
            return "<redacted>"
        }
        return argument
    }

}

private struct VoiceTutorProviderSelection {
    let provider: any VoiceTutorProvider
    let usesPocketLatencyLogs: Bool
}
