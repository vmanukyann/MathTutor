import SwiftUI

struct VoiceDebugPanel: View {
    @ObservedObject var recognizer: VoiceCommandRecognizer

    private let simulatedCommands: [VoiceCommand] = [
        .startSession,
        .enterTeachMode,
        .returnToWork,
        .askQuestion,
        .checkWork,
        .hearingTest,
        .connectAirPlay,
        .displayOnScreen,
        .markCorrected,
        .endSession,
        .emergencyStop,
        .confirmUnderstood
    ]

    var body: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 16) {
                MTSectionHeader(
                    title: "Voice Debug",
                    subtitle: "Development-only command inspection and simulation."
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    debugRow("Permission", recognizer.snapshot.permissionStatus.displayName, "lock.shield")
                    debugRow("Microphone", recognizer.snapshot.isMicrophoneAuthorized ? "Authorized" : "Not authorized", "mic")
                    debugRow("Listening", recognizer.snapshot.isListening ? "Yes" : "No", "mic")
                    debugRow("Mode", recognizer.snapshot.currentVoiceMode.displayName, "waveform")
                    debugRow("Command", recognizer.snapshot.lastRecognizedCommand?.displayName ?? "None", "command")
                    debugRow("Action", recognizer.snapshot.routedAction.isEmpty ? "None" : recognizer.snapshot.routedAction, "arrow.triangle.branch")
                    debugRow("Confidence", confidenceText, "gauge.with.dots.needle.bottom.50percent")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MTTheme.secondaryInk)
                    Text(recognizer.snapshot.lastTranscript.isEmpty ? "None" : recognizer.snapshot.lastTranscript)
                        .font(.callout)
                        .foregroundStyle(MTTheme.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                }

                if let lastError = recognizer.snapshot.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(MTTheme.errorRust)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await recognizer.startListening() }
                    } label: {
                        Label("Start Listening", systemImage: "mic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MTSecondaryButton())

                    Button {
                        recognizer.stopListening()
                    } label: {
                        Label("Stop Listening", systemImage: "mic.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MTSecondaryButton())
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(simulatedCommands) { command in
                        Button {
                            recognizer.simulate(command)
                        } label: {
                            Label(command.displayName, systemImage: command.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MTSecondaryButton())
                    }
                }
            }
        }
    }

    private var confidenceText: String {
        guard let confidence = recognizer.snapshot.confidence else { return "None" }
        return "\(Int(confidence * 100))%"
    }

    private func debugRow(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(MTTheme.chalkboardGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MTTheme.secondaryInk)
                Text(value)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(MTTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .padding(10)
        .background(MTTheme.notebookPaper.opacity(0.78), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
    }
}
