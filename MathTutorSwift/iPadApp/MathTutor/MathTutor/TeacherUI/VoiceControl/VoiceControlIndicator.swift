import SwiftUI

struct VoiceControlIndicator: View {
    let snapshot: VoiceControlSnapshot
    var onRestart: (() -> Void)?

    var body: some View {
        Group {
            if let onRestart {
                Button(action: onRestart) {
                    indicator
                }
                .buttonStyle(.plain)
                .accessibilityHint("Restarts voice control")
            } else {
                indicator
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var indicator: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))

            if onRestart != nil {
                Text(statusText)
                    .font(.caption2.weight(.semibold))
            }
        }
            .foregroundStyle(tint)
            .padding(.horizontal, onRestart == nil ? 0 : 9)
            .frame(minWidth: 32, minHeight: 32)
            .background(MTTheme.notebookPaper.opacity(0.92), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 1)
            }
    }

    private var statusText: String {
        if !snapshot.isMicrophoneAuthorized {
            return "Mic off"
        }
        if snapshot.isListening {
            return snapshot.lastTranscript.isEmpty ? "Listening" : "Heard you"
        }
        return "Tap to start"
    }

    private var iconName: String {
        switch snapshot.currentVoiceMode {
        case .disabled:
            return "mic.slash"
        case .askingQuestion:
            return "questionmark"
        case .processing:
            return "mic.badge.plus"
        case .idle, .listening:
            return snapshot.isListening ? "mic" : "mic.slash"
        }
    }

    private var tint: Color {
        switch snapshot.currentVoiceMode {
        case .disabled:
            return MTTheme.disabledGray
        case .askingQuestion:
            return MTTheme.chemicalGold
        case .processing:
            return MTTheme.labGreen
        case .idle:
            return MTTheme.disabledGray
        case .listening:
            return MTTheme.labGreen
        }
    }

    private var accessibilityLabel: String {
        switch snapshot.currentVoiceMode {
        case .disabled: "Voice control disabled"
        case .idle: "Voice control idle"
        case .listening: "Voice control listening"
        case .processing: "Voice control processing"
        case .askingQuestion: "Voice control listening for question"
        }
    }
}
