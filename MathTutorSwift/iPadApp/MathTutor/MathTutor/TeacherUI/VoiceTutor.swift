import AVFoundation
import Combine

@MainActor
final class VoiceTutor: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
            )
            try audioSession.setActive(true)
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            // AVSpeechSynthesizer can still attempt playback with the current session.
        }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: spokenText(from: text))
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func spokenText(from source: String) -> String {
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
