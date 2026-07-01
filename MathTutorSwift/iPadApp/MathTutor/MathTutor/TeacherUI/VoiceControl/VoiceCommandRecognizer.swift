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
    private var lastCommandDate = Date.distantPast

    var lastRecognizedCommand: VoiceCommand? {
        snapshot.lastRecognizedCommand
    }

    override init() {
        super.init()
        snapshot.isAvailable = speechRecognizer?.isAvailable ?? false
        snapshot.permissionStatus = VoicePermissionStatus(speechStatus: SFSpeechRecognizer.authorizationStatus())
        snapshot.currentVoiceMode = snapshot.permissionStatus == .authorized ? .idle : .disabled
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
        if snapshot.permissionStatus != .authorized || !microphoneAuthorized {
            snapshot.currentVoiceMode = .disabled
            snapshot.isListening = false
            snapshot.lastError = microphoneAuthorized
                ? "Speech recognition is not authorized."
                : "Microphone access is not authorized."
        }
    }

    func startListening() async {
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
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition == true
        }
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
            shouldKeepListening = false
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
            stopRecognitionSession()
            return
        }

        snapshot.isListening = true
        snapshot.isAvailable = speechRecognizer?.isAvailable ?? false
        snapshot.currentVoiceMode = .listening
        snapshot.lastTranscript = ""
        snapshot.lastError = nil

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognition(result: result, error: error)
            }
        }
    }

    private func stopRecognitionSession() {
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
               shouldEmit(match) {
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
        guard phrase != lastCommandPhrase || elapsed > 1.25 else { return false }
        lastCommandPhrase = phrase
        lastCommandDate = Date()
        return true
    }

    private func restartRecognitionSoon() {
        stopRecognitionSession()
        guard shouldKeepListening else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard shouldKeepListening else { return }
            startRecognitionSession()
        }
    }
}
