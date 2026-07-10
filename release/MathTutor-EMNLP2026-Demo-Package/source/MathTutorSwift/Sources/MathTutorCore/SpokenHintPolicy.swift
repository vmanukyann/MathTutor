import Foundation

public struct HintPresentation: Equatable, Sendable {
    public var explanation: String
    public var action: String

    public init(explanation: String, action: String) {
        self.explanation = explanation
        self.action = action
    }

    public var combinedText: String {
        "\(explanation)\nTry: \(action)"
    }
}

public enum SpokenHintPolicy {
    private static let fallbackPresentation = HintPresentation(
        explanation: "The first incorrect line changes the operation used in the line before it.",
        action: "Identify that changed operation, then redo only this transition."
    )
    private static let fallbackSpeech = """
    The first incorrect line changes the operation used before it. \
    Identify that change, then redo only this transition.
    """

    public static func presentation(
        explanation: String?,
        action: String?,
        legacyHint: String
    ) -> HintPresentation {
        let providedExplanation = explanation?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let providedAction = action?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^try\s*:\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ) ?? ""

        if let completeExplanation = completeSentence(providedExplanation),
           let completeAction = completeSentence(providedAction) {
            return HintPresentation(
                explanation: completeExplanation,
                action: completeAction
            )
        }

        let legacyParts = legacySentences(legacyHint)
        guard legacyParts.count >= 2,
              let completeExplanation = completeSentence(
                  legacyParts.dropLast().joined(separator: " ")
              ),
              let completeAction = completeSentence(legacyParts.last ?? "") else {
            return fallbackPresentation
        }
        return HintPresentation(explanation: completeExplanation, action: completeAction)
    }

    public static func spokenText(for presentation: HintPresentation) -> String {
        presentation.combinedText
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
            .replacingOccurrences(
                of: #"\s{2,}"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func playbackText(
        spokenHint: String?,
        presentation: HintPresentation
    ) -> String {
        let candidate = sanitizeSpeech(spokenHint ?? "")
        if isCompleteSpeech(candidate) {
            return firstConciseHint(candidate)
        }

        let derived = spokenText(for: presentation)
        return firstConciseHint(isCompleteSpeech(derived) ? derived : fallbackSpeech)
    }

    public static func forPlayback(spokenHint: String?, fallback: String) -> String {
        let preferred = spokenHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return shortened(preferred.isEmpty ? fallback : preferred)
    }

    public static func shortened(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func speechChunks(
        _ source: String,
        minimumWords: Int = 20,
        maximumWords: Int = 35
    ) -> [String] {
        let cleaned = sanitizeSpeech(source)
        guard !cleaned.isEmpty else { return [] }

        let sentences = legacySentences(cleaned)
        var chunks: [String] = []
        var pending = ""

        for sentence in sentences {
            let candidate = pending.isEmpty ? sentence : "\(pending) \(sentence)"
            let candidateWords = wordCount(candidate)
            let pendingWords = wordCount(pending)
            let sentenceWords = wordCount(sentence)

            if candidateWords <= maximumWords || pendingWords < minimumWords {
                pending = candidate
            } else if sentenceWords < 8 {
                pending = candidate
            } else {
                appendSplitChunks(pending, maximumWords: maximumWords, to: &chunks)
                pending = sentence
            }
        }

        appendSplitChunks(pending, maximumWords: maximumWords, to: &chunks)
        return chunks
            .map { completeSentence($0) ?? $0 }
            .filter { !$0.isEmpty }
    }

    private static func completeSentence(_ source: String) -> String? {
        guard !source.isEmpty else { return nil }
        var result = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",:;—-"))
        if !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        return result
    }

    private static func sanitizeSpeech(_ source: String) -> String {
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
            .replacingOccurrences(
                of: #"\s{2,}"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendSplitChunks(
        _ source: String,
        maximumWords: Int,
        to chunks: inout [String]
    ) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard words.count > maximumWords else {
            chunks.append(trimmed)
            return
        }

        var cursor = 0
        while cursor < words.count {
            let next = min(cursor + maximumWords, words.count)
            var chunkEnd = next
            if next < words.count,
               let boundary = preferredSplitBoundary(in: words, from: cursor, to: next) {
                chunkEnd = boundary
            }
            chunks.append(words[cursor..<chunkEnd].joined(separator: " "))
            cursor = chunkEnd
        }
    }

    private static func preferredSplitBoundary(
        in words: [String],
        from start: Int,
        to proposedEnd: Int
    ) -> Int? {
        let minimumEnd = min(start + 20, proposedEnd)
        guard proposedEnd > minimumEnd else { return nil }

        for index in stride(from: proposedEnd - 1, through: minimumEnd, by: -1) {
            let word = words[index]
            if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
                return index + 1
            }
        }
        return nil
    }

    private static func wordCount(_ source: String) -> Int {
        source.split(whereSeparator: { $0.isWhitespace }).count
    }

    private static func firstConciseHint(_ source: String) -> String {
        speechChunks(source, minimumWords: 15, maximumWords: 35).first
            ?? fallbackSpeech
    }

    private static func isCompleteSpeech(_ source: String) -> Bool {
        let genericPhrases = [
            "more careful explanation",
            "check this step carefully",
            "compare it with the previous line",
            "that step changes the operation incorrectly",
            "check the marked line again"
        ]
        let lowercased = source.lowercased()
        return !source.isEmpty &&
            !genericPhrases.contains(where: lowercased.contains) &&
            (source.hasSuffix(".") || source.hasSuffix("!") || source.hasSuffix("?"))
    }

    private static func legacySentences(_ source: String) -> [String] {
        let flattened = source.replacingOccurrences(of: "\n", with: " ")
        guard let regex = try? NSRegularExpression(pattern: #"[^.!?]+[.!?]?"#) else {
            return [flattened]
        }
        let range = NSRange(flattened.startIndex..<flattened.endIndex, in: flattened)
        return regex.matches(in: flattened, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: flattened) else { return nil }
            let sentence = flattened[matchRange].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
    }
}
