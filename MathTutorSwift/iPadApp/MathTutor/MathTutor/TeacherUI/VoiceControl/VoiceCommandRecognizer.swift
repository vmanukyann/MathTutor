 import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceCommandRecognizer: NSObject, ObservableObject {
    @Published private(set) var snapshot = VoiceControlSnapshot()
    @Published private(set) var commandEventID = UUID()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var shouldKeepListening = false
    private var lastCommandPhrase = ""
    private var lastCommand: VoiceCommand?
    private var lastCommandDate = Date.distantPast
    private var recognitionGeneration = UUID()
    private var restartTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var isTutorSpeaking = false

    var lastRecognizedCommand: VoiceCommand? {
        snapshot.lastRecognizedCommand
    }

    override init() {
        super.init()
        snapshot.isAvailable = speechRecognizer?.isAvailable ?? false
        snapshot.permissionStatus = VoicePermissionStatus(speechStatus: SFSpeechRecognizer.authorizationStatus())
        snapshot.currentVoiceMode = snapshot.permissionStatus == .authorized ? .idle : .disabled
        observeAudioLifecycle()
    }

    deinit {
        restartTask?.cancel()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func requestPermissionsIfNeeded() async {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }

        let microphoneAuthorized = await requestMicrophonePermissionIfNeeded()

        snapshot.permissionStatus = VoicePermissionStatus(speechStatus: SFSpeechRecognizer.authorizationStatus())
        snapshot.isMicrophoneAuthorized = microphoneAuthorized
        snapshot.isAvailable = speechRecognizer?.isAvailable ?? false
        print(
            "MathTutorVoice permissions speech=\(snapshot.permissionStatus.displayName) "
                + "microphone=\(microphoneAuthorized) available=\(snapshot.isAvailable)"
        )
        if snapshot.permissionStatus != .authorized || !microphoneAuthorized {
            snapshot.currentVoiceMode = .disabled
            snapshot.isListening = false
            snapshot.lastError = microphoneAuthorized
                ? "Speech recognition is not authorized."
                : "Microphone access is not authorized."
        }
    }

    func startListening() async {
        print("MathTutorVoice start requested")
        await requestPermissionsIfNeeded()
        guard snapshot.permissionStatus == .authorized else {
            snapshot.lastError = "Speech recognition is not authorized."
            snapshot.currentVoiceMode = .disabled
            return
        }
        guard snapshot.isMicrophoneAuthorized else {
            snapshot.lastError = "Microphone access is not authorized. Enable it in Settings."
            snapshot.currentVoiceMode = .disabled
            return
        }
        guard speechRecognizer?.isAvailable == true else {
            snapshot.lastError = "Speech recognition is unavailable."
            snapshot.currentVoiceMode = .disabled
            return
        }

        shouldKeepListening = true
        startRecognitionSession()
    }

    func ensureListening() async {
        guard !snapshot.isListening else { return }
        await startListening()
    }

    func stopListening() {
        shouldKeepListening = false
        restartTask?.cancel()
        restartTask = nil
        stopRecognitionSession()
        snapshot.currentVoiceMode = snapshot.permissionStatus == .authorized ? .idle : .disabled
    }

    func setQuestionMode(_ isAskingQuestion: Bool) {
        guard snapshot.permissionStatus == .authorized else { return }
        snapshot.currentVoiceMode = isAskingQuestion ? .askingQuestion : (snapshot.isListening ? .listening : .idle)
    }

    func simulate(_ command: VoiceCommand, transcript: String? = nil) {
        let phrase = transcript ?? command.displayName
        snapshot.lastTranscript = phrase
        snapshot.lastRecognizedCommand = command
        snapshot.confidence = 1
        snapshot.currentVoiceMode = .processing
        commandEventID = UUID()
        snapshot.currentVoiceMode = snapshot.isListening ? .listening : .idle
    }

    func recordRoutedAction(_ action: String) {
        snapshot.routedAction = action
    }

    func setTutorSpeaking(_ speaking: Bool) {
        guard isTutorSpeaking != speaking else { return }
        isTutorSpeaking = speaking

        if !speaking, shouldKeepListening {
            // Start with a clean transcript so the tutor's own speech cannot become
            // the next student command.
            restartRecognitionSoon()
        }
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func startRecognitionSession() {
        restartTask?.cancel()
        restartTask = nil
        stopRecognitionSession()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            snapshot.lastError = error.localizedDescription
            snapshot.currentVoiceMode = .disabled
            print("MathTutorVoice audio session failed: \(error.localizedDescription)")
            scheduleRecognitionRestart()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = [
            "can you hear me",
            "check my work",
            "check what I am pointing to",
            "display this on the screen",
            "show me how to do this",
            "show me a hint",
            "pause",
            "resume",
            "repeat this",
            "mark fixed",
            "end session"
        ]
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            snapshot.lastError = "Microphone input is unavailable."
            snapshot.currentVoiceMode = .disabled
            snapshot.isListening = false
            recognitionRequest = nil
            print(
                "MathTutorVoice invalid input format "
                    + "sampleRate=\(format.sampleRate) channels=\(format.channelCount)"
            )
            scheduleRecognitionRestart()
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            snapshot.lastError = error.localizedDescription
            print("MathTutorVoice audio engine failed: \(error.localizedDescription)")
            stopRecognitionSession()
            scheduleRecognitionRestart()
            return
        }

        snapshot.isListening = true
        snapshot.isAvailable = speechRecognizer?.isAvailable ?? false
        snapshot.currentVoiceMode = .listening
        snapshot.lastTranscript = ""
        snapshot.lastError = nil
        print(
            "MathTutorVoice listening sampleRate=\(format.sampleRate) "
                + "channels=\(format.channelCount)"
        )

        let generation = UUID()
        recognitionGeneration = generation
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard self?.recognitionGeneration == generation else { return }
                self?.handleRecognition(result: result, error: error)
            }
        }
    }

    private func stopRecognitionSession() {
        recognitionGeneration = UUID()
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        snapshot.isListening = false
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let transcript = result.bestTranscription.formattedString
            snapshot.lastTranscript = transcript
            snapshot.confidence = result.bestTranscription.segments.last.map { Double($0.confidence) }

            if let match = VoiceCommandParser.parse(
                transcript,
                confidence: snapshot.confidence,
                allowGenericQuestion: result.isFinal
            ),
               (!isTutorSpeaking || match.command == .pause || match.command == .emergencyStop),
               shouldEmit(match) {
                print("MathTutorVoice command=\(match.command.rawValue) phrase=\(match.phrase)")
                snapshot.lastRecognizedCommand = match.command
                snapshot.currentVoiceMode = .processing
                commandEventID = UUID()
                snapshot.currentVoiceMode = snapshot.isListening ? .listening : .idle
            }

            if result.isFinal, shouldKeepListening {
                restartRecognitionSoon()
            }
        }

        if let error {
            snapshot.lastError = error.localizedDescription
            print("MathTutorVoice recognition error: \(error.localizedDescription)")
            if shouldKeepListening {
                restartRecognitionSoon()
            } else {
                stopRecognitionSession()
            }
        }
    }

    private func shouldEmit(_ match: VoiceCommandMatch) -> Bool {
        let phrase = match.phrase.lowercased()
        let elapsed = Date().timeIntervalSince(lastCommandDate)
        guard match.command != lastCommand || elapsed > 3 else { return false }
        guard phrase != lastCommandPhrase || elapsed > 1.25 else { return false }
        lastCommand = match.command
        lastCommandPhrase = phrase
        lastCommandDate = Date()
        return true
    }

    private func restartRecognitionSoon() {
        stopRecognitionSession()
        scheduleRecognitionRestart(after: 0.35)
    }

    private func scheduleRecognitionRestart(after delay: TimeInterval = 0.8) {
        guard shouldKeepListening else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, shouldKeepListening else { return }
            startRecognitionSession()
        }
    }

    private func observeAudioLifecycle() {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self,
                          let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: rawType),
                          type == .ended else { return }
                    print("MathTutorVoice interruption ended")
                    scheduleRecognitionRestart(after: 0.2)
                }
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    if let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                       AVAudioSession.RouteChangeReason(rawValue: rawReason) == .categoryChange {
                        return
                    }
                    print("MathTutorVoice audio route changed")
                    self?.scheduleRecognitionRestart(after: 0.35)
                }
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    print("MathTutorVoice media services reset")
                    self?.scheduleRecognitionRestart(after: 0.5)
                }
            }
        ]
    }

}
