import SwiftUI

struct VoiceControlIndicator: View {
    let snapshot: VoiceControlSnapshot

    var body: some View {
        Image(systemName: iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(MTTheme.notebookPaper.opacity(0.92), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                    .stroke(tint.opacity(0.42), lineWidth: 1)
            }
            .accessibilityLabel(accessibilityLabel)
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
