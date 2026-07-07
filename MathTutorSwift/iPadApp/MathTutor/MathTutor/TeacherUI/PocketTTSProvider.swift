import Foundation
import FluidAudio

final class PocketTTSProvider: VoiceTutorProvider, @unchecked Sendable {
    static let shared = PocketTTSProvider(configuration: .fromLaunchArguments())

    private let runtime: PocketTTSRuntime
    private let configuration: PocketTTSConfiguration

    init(configuration: PocketTTSConfiguration) {
        self.configuration = configuration
        self.runtime = PocketTTSRuntime(configuration: configuration)
        PocketTTSLatencyTrace(requestID: "prewarm").log(
            "prewarm_disabled",
            fields: ["reason": "pocket_experimental_opt_in_only"]
        )
    }

    func audio(for text: String, requestID: String) async throws -> Data {
        let normalizedText = MathSpeechNormalizer.normalize(text)
        guard !normalizedText.isEmpty else {
            throw PocketTTSError.emptyText
        }

        let trace = PocketTTSLatencyTrace(requestID: requestID)
        let audio = try await runtime.synthesize(normalizedText, trace: trace)

        if configuration.exportDiagnosticAudio {
            let outputURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("mathtutor_pocket_tts_diagnostic.wav")
            try? audio.write(to: outputURL, options: .atomic)
            trace.log("diagnostic_wav_exported", fields: [
                "path": outputURL.path,
            ])
        }

        return audio
    }
}

struct PocketTTSConfiguration: Sendable {
    var builtInVoice: String?
    var voicePrompt: PocketTTSVoicePrompt?
    var requiresCustomVoicePrompt: Bool
    var exportDiagnosticAudio: Bool
    var resetModelCache: Bool
    var language: PocketTtsLanguage
    var precision: PocketTtsPrecision

    static func fromLaunchArguments(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PocketTTSConfiguration {
        let isDiagnostic = arguments.contains("--run-pocket-tts-diagnostic")
        let builtInVoice = TTSLaunchArguments.launchArgumentValue(
            named: "--pocket-tts-voice",
            arguments: arguments
        ) ?? environment["MATHTUTOR_POCKET_TTS_VOICE"]

        let explicitPrompt = TTSLaunchArguments.launchArgumentValue(
            named: "--pocket-voice-prompt",
            arguments: arguments
        ) ?? environment["MATHTUTOR_POCKET_VOICE_PROMPT"]

        let voicePrompt = resolveVoicePrompt(explicitPath: explicitPrompt)
        let language = parseLanguage(
            TTSLaunchArguments.launchArgumentValue(
                named: "--pockettts-language",
                arguments: arguments
            ) ?? environment["MATHTUTOR_POCKETTTS_LANGUAGE"]
        )
        let precision = parsePrecision(
            TTSLaunchArguments.launchArgumentValue(
                named: "--pockettts-precision",
                arguments: arguments
            ) ?? environment["MATHTUTOR_POCKETTTS_PRECISION"]
        )

        return PocketTTSConfiguration(
            builtInVoice: builtInVoice,
            voicePrompt: voicePrompt,
            requiresCustomVoicePrompt: isDiagnostic || builtInVoice == nil,
            exportDiagnosticAudio: isDiagnostic,
            resetModelCache: arguments.contains("--reset-pockettts-cache"),
            language: language,
            precision: precision
        )
    }

    private static func resolveVoicePrompt(explicitPath: String?) -> PocketTTSVoicePrompt? {
        if let explicitPath, !explicitPath.isEmpty {
            return PocketTTSVoicePrompt(
                url: URL(fileURLWithPath: explicitPath),
                source: "launch_argument",
                displayName: explicitPath
            )
        }

        if let bundleURL = Bundle.main.url(
            forResource: "voice",
            withExtension: "wav",
            subdirectory: "Resources"
        ) ?? Bundle.main.url(forResource: "voice", withExtension: "wav") {
            return PocketTTSVoicePrompt(
                url: bundleURL,
                source: "bundle",
                displayName: bundleURL.lastPathComponent
            )
        }

        if let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {
            let documentsURL = documents
                .appendingPathComponent("MathTutor", isDirectory: true)
                .appendingPathComponent("voice.wav")
            if FileManager.default.fileExists(atPath: documentsURL.path) {
                return PocketTTSVoicePrompt(
                    url: documentsURL,
                    source: "documents",
                    displayName: documentsURL.path
                )
            }
        }

        return nil
    }

    private static func parseLanguage(_ value: String?) -> PocketTtsLanguage {
        guard let value,
              let language = PocketTtsLanguage(rawValue: value) else {
            return .english
        }
        return language
    }

    private static func parsePrecision(_ value: String?) -> PocketTtsPrecision {
        switch value?.lowercased() {
        case "int8":
            return .int8
        default:
            return .fp16
        }
    }
}

struct PocketTTSVoicePrompt: Sendable {
    var url: URL
    var source: String
    var displayName: String
}

private actor PocketTTSRuntime {
    private let configuration: PocketTTSConfiguration
    private let manager: PocketTtsManager
    private var isPrepared = false
    private var clonedVoiceData: PocketTtsVoiceData?
    private var didHandleResetFlag = false
    private var didRepairInvalidModelCache = false
    private var preparationTask: Task<Void, Error>?

    init(configuration: PocketTTSConfiguration) {
        self.configuration = configuration
        self.manager = PocketTtsManager(
            defaultVoice: configuration.builtInVoice ?? "alba",
            language: configuration.language,
            precision: configuration.precision
        )
    }

    func prewarm() async {
        let trace = PocketTTSLatencyTrace(requestID: "prewarm")
        do {
            try await prepareSingleFlight(trace: trace)
        } catch {
            trace.log(
                "voice_preparation_failed",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    func synthesize(_ text: String, trace: PocketTTSLatencyTrace) async throws -> Data {
        trace.log("voice_preparation_started")
        print("mathtutor_pockettts_latency voice_preparation_started=true request_id=\(trace.requestID)")
        let cachedVoiceUsed = isPrepared
        try await prepareSingleFlight(trace: trace)
        trace.log("voice_preparation_finished", fields: [
            "cached_voice_used": "\(cachedVoiceUsed)",
        ])
        print(
            "mathtutor_pockettts_latency voice_preparation_finished=true request_id=\(trace.requestID) cached_voice_used=\(cachedVoiceUsed)"
        )

        trace.log("synthesis_started", fields: [
            "mode": "full_wav",
            "streaming": "false",
            "voice_source": voiceSourceDescription,
        ])

        let audio: Data
        if let clonedVoiceData {
            audio = try await manager.synthesize(text: text, voiceData: clonedVoiceData)
        } else if let builtInVoice = configuration.builtInVoice {
            trace.log("using_explicit_builtin_voice", fields: [
                "voice": builtInVoice,
            ])
            audio = try await manager.synthesize(text: text, voice: builtInVoice)
        } else {
            throw PocketTTSError.noCustomVoicePrompt
        }

        trace.log("first_frame_received", fields: [
            "mode": "full_wav_after_synthesis",
        ])
        trace.log("first_coalesced_buffer_scheduled", fields: [
            "mode": "full_wav_single_file",
        ])
        trace.log("synthesis_finished", fields: [
            "bytes": "\(audio.count)",
        ])
        return audio
    }

    private func prepareSingleFlight(trace: PocketTTSLatencyTrace) async throws {
        trace.log("pocket_prepare_requested")
        if isPrepared {
            trace.log("pocket_prepare_singleflight_reused", fields: ["value": "false"])
            trace.log("voice_cache_ready", fields: [
                "cached_voice_used": "true",
                "voice_source": voiceSourceDescription,
            ])
            return
        }

        if let preparationTask {
            trace.log("pocket_prepare_singleflight_reused", fields: ["value": "true"])
            try await preparationTask.value
            return
        }

        trace.log("pocket_prepare_singleflight_reused", fields: ["value": "false"])
        let task = Task {
            try await self.prepare(trace: trace)
        }
        preparationTask = task
        do {
            try await task.value
            preparationTask = nil
        } catch {
            preparationTask = nil
            throw error
        }
    }

    private func prepare(trace: PocketTTSLatencyTrace) async throws {
        trace.log("pocket_prepare_started")
        guard configuration.voicePrompt != nil || !configuration.requiresCustomVoicePrompt else {
            trace.log("voice_prompt_missing", fields: [
                "error": "no_custom_voice_prompt_found",
            ])
            trace.log("pocket_prepare_failed", fields: [
                "error": PocketTTSError.noCustomVoicePrompt.localizedDescription,
            ])
            print("mathtutor_pockettts_latency voice_prompt_found=false")
            throw PocketTTSError.noCustomVoicePrompt
        }

        await PocketTTSModelCacheCoordinator.shared.acquire(trace: trace)
        do {
            try await prepareWithModelCacheLock(trace: trace)
            await PocketTTSModelCacheCoordinator.shared.release(trace: trace)
        } catch {
            await PocketTTSModelCacheCoordinator.shared.release(trace: trace)
            throw error
        }
    }

    private func prepareWithModelCacheLock(trace: PocketTTSLatencyTrace) async throws {
        if configuration.resetModelCache, !didHandleResetFlag {
            didHandleResetFlag = true
            try resetPocketTTSModelCache(trace: trace, reason: "launch_argument")
        }

        do {
            trace.log("model_configuration", fields: [
                "language": configuration.language.rawValue,
                "precision": "\(configuration.precision)",
            ])
            try await manager.initialize()
        } catch {
            trace.log("model_load_failed", fields: [
                "error": error.localizedDescription,
                "failed_model_path": failedModelPath(from: error.localizedDescription) ?? "unknown",
                "language": configuration.language.rawValue,
                "precision": "\(configuration.precision)",
            ])
            let shouldRepairInvalidModel = isInvalidCompiledModelError(error)
            let shouldRepairCacheCollision = isCacheCollisionError(error)
            if shouldRepairCacheCollision {
                trace.log("cache_collision_detected", fields: [
                    "error": error.localizedDescription,
                ])
            }
            guard (shouldRepairInvalidModel || shouldRepairCacheCollision),
                  !didRepairInvalidModelCache else {
                trace.log("pocket_prepare_failed", fields: [
                    "error": error.localizedDescription,
                ])
                throw error
            }
            didRepairInvalidModelCache = true
            try resetPocketTTSModelCache(
                trace: trace,
                reason: shouldRepairCacheCollision ? "cache_collision" : "invalid_mlmodelc"
            )
            trace.log("retry_started", fields: [
                "language": configuration.language.rawValue,
                "precision": "\(configuration.precision)",
            ])
            do {
                try await manager.initialize()
                trace.log("retry_finished", fields: ["success": "true"])
                trace.log("model_load_retry_succeeded")
            } catch {
                trace.log("retry_finished", fields: [
                    "success": "false",
                    "error": error.localizedDescription,
                ])
                trace.log("pocket_prepare_failed", fields: [
                    "error": error.localizedDescription,
                ])
                throw error
            }
        }
        if let voicePrompt = configuration.voicePrompt {
            trace.log("voice_prompt_found", fields: [
                "path": voicePrompt.displayName,
                "source": voicePrompt.source,
            ])
            print("mathtutor_pockettts_latency voice_prompt_found=true")
            print("mathtutor_pockettts_latency voice_prompt_path=\(voicePrompt.displayName)")
            let cachedVoiceURL = cachedVoiceDataURL(for: voicePrompt.url)
            if FileManager.default.fileExists(atPath: cachedVoiceURL.path) {
                clonedVoiceData = try manager.loadClonedVoice(from: cachedVoiceURL)
                trace.log("voice_prompt_cache_loaded", fields: [
                    "cached_voice_used": "true",
                    "source": voicePrompt.source,
                ])
            } else {
                trace.log("voice_prompt_clone_started", fields: [
                    "source": voicePrompt.source,
                ])
                let voiceData = try await manager.cloneVoice(from: voicePrompt.url)
                clonedVoiceData = voiceData
                try? FileManager.default.createDirectory(
                    at: cachedVoiceURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                do {
                    try manager.saveClonedVoice(voiceData, to: cachedVoiceURL)
                    trace.log("voice_prompt_cache_saved", fields: [
                        "path": cachedVoiceURL.path,
                    ])
                } catch {
                    trace.log("voice_prompt_cache_save_failed", fields: [
                        "error": error.localizedDescription,
                    ])
                }
                trace.log("voice_prompt_clone_finished", fields: [
                    "cached_voice_used": "false",
                    "source": voicePrompt.source,
                ])
            }
        } else if let builtInVoice = configuration.builtInVoice {
            trace.log("using_explicit_builtin_voice", fields: [
                "voice": builtInVoice,
            ])
        } else {
            trace.log("default_voice_rejected", fields: [
                "error": "Pocket TTS diagnostic failed: no custom voice prompt found",
            ])
            throw PocketTTSError.noCustomVoicePrompt
        }
        isPrepared = true
        trace.log("voice_cache_ready", fields: [
            "cached_voice_used": "\(clonedVoiceData != nil)",
            "voice_source": voiceSourceDescription,
        ])
        trace.log("pocket_prepare_finished")
    }

    private var voiceSourceDescription: String {
        if let voicePrompt = configuration.voicePrompt {
            return voicePrompt.source
        }
        if configuration.builtInVoice != nil {
            return "explicit_builtin_voice"
        }
        return "missing_custom_voice_prompt"
    }

    private func resetPocketTTSModelCache(
        trace: PocketTTSLatencyTrace,
        reason: String
    ) throws {
        let cacheURL = try pocketTTSModelCacheURL()
        trace.log("cache_repair_started", fields: [
            "path": cacheURL.path,
            "reason": reason,
        ])
        trace.log("model_cache_reset_started", fields: [
            "path": cacheURL.path,
            "reason": reason,
        ])
        let existed = FileManager.default.fileExists(atPath: cacheURL.path)
        if existed {
            do {
                try FileManager.default.removeItem(at: cacheURL)
            } catch {
                trace.log("model_cache_reset_failed", fields: [
                    "error": error.localizedDescription,
                    "path": cacheURL.path,
                ])
                trace.log("cache_repair_finished", fields: [
                    "success": "false",
                    "error": error.localizedDescription,
                ])
                throw error
            }
            trace.log("model_cache_reset_finished", fields: [
                "deleted": "true",
                "path": cacheURL.path,
            ])
        } else {
            trace.log("model_cache_reset_finished", fields: [
                "deleted": "false",
                "path": cacheURL.path,
            ])
        }
        trace.log("cache_repair_finished", fields: [
            "deleted": "\(existed)",
            "success": "true",
        ])
    }

    private func pocketTTSModelCacheURL() throws -> URL {
        try TtsCacheDirectory.ensure()
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("pocket-tts", isDirectory: true)
    }

    private func isInvalidCompiledModelError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not a valid .mlmodelc")
            || message.contains("compile the model with xcode")
            || message.contains("mlmodel.compilemodel")
            || message.contains("unable to load model")
    }

    private func isCacheCollisionError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("couldn’t be moved")
            || message.contains("couldn't be moved")
            || message.contains("item with the same name already exists")
            || message.contains("cfnetworkdownload")
    }

    private func failedModelPath(from message: String) -> String? {
        guard let start = message.range(of: "/") else {
            return nil
        }
        let tail = message[start.lowerBound...]
        if let end = tail.range(of: ". It is") {
            return String(tail[..<end.lowerBound])
        }
        if let end = tail.range(of: ". Compile") {
            return String(tail[..<end.lowerBound])
        }
        return String(tail)
    }

    private func cachedVoiceDataURL(for promptURL: URL) -> URL {
        let attributes = try? FileManager.default.attributesOfItem(atPath: promptURL.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let fingerprint = stableFingerprint(
            "\(promptURL.path)-\(size)-\(Int(modified))"
        )
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("MathTutor", isDirectory: true)
            .appendingPathComponent("PocketTTS", isDirectory: true)
            .appendingPathComponent("voice_\(fingerprint).bin")
    }

    private func stableFingerprint(_ source: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

private actor PocketTTSModelCacheCoordinator {
    static let shared = PocketTTSModelCacheCoordinator()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire(trace: PocketTTSLatencyTrace) async {
        trace.log("pocket_prepare_global_lock_requested")
        if !isLocked {
            isLocked = true
            trace.log("pocket_prepare_global_lock_acquired", fields: [
                "waited": "false",
            ])
            return
        }

        trace.log("pocket_prepare_global_lock_waiting", fields: [
            "waiters": "\(waiters.count + 1)",
        ])
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        trace.log("pocket_prepare_global_lock_acquired", fields: [
            "waited": "true",
        ])
    }

    func release(trace: PocketTTSLatencyTrace) {
        if waiters.isEmpty {
            isLocked = false
            trace.log("pocket_prepare_global_lock_released", fields: [
                "next_waiter": "false",
            ])
        } else {
            let next = waiters.removeFirst()
            trace.log("pocket_prepare_global_lock_released", fields: [
                "next_waiter": "true",
                "remaining_waiters": "\(waiters.count)",
            ])
            next.resume()
        }
    }
}

private enum PocketTTSError: LocalizedError {
    case emptyText
    case noCustomVoicePrompt

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "There is no text to speak."
        case .noCustomVoicePrompt:
            "Pocket TTS diagnostic failed: no custom voice prompt found"
        }
    }
}

final class PocketTTSLatencyTrace: @unchecked Sendable {
    private let clock = ContinuousClock()
    private let startedAt: ContinuousClock.Instant
    let requestID: String

    nonisolated init(requestID: String) {
        self.requestID = requestID
        self.startedAt = clock.now
    }

    nonisolated func log(_ event: String, fields: [String: String] = [:]) {
        let elapsed = startedAt.duration(to: clock.now)
        let milliseconds = elapsed.components.seconds * 1_000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
        let suffix = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let message =
            "mathtutor_pockettts_latency event=\(event) request_id=\(requestID) elapsed_ms=\(milliseconds)"
        print(suffix.isEmpty ? message : "\(message) \(suffix)")
    }
}
