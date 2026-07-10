import Foundation

public enum MathSpeechNormalizer {
    public static func normalize(_ source: String) -> String {
        var result = source
            .replacingOccurrences(of: "\n", with: " ")

        result = replacingMatches(
            in: result,
            pattern: #"\b([0-9]|1[0-9]|20)\s*/\s*([2-9]|10)\b"#
        ) { match in
            guard let numerator = integer(in: match, rangeAt: 1),
                  let denominator = integer(in: match, rangeAt: 2),
                  let numeratorWord = numberWords[numerator],
                  let denominatorWord = denominatorWords[denominator] else {
                return nil
            }
            let spokenDenominator = numerator == 1
                ? denominatorWord.singular
                : denominatorWord.plural
            return "\(numeratorWord) \(spokenDenominator)"
        }

        result = replacingMatches(
            in: result,
            pattern: #"\b([0-9]|1[0-9]|20)\s*([A-Za-z])\b"#
        ) { match in
            guard let coefficient = integer(in: match, rangeAt: 1),
                  let coefficientWord = numberWords[coefficient],
                  let variableRange = Range(match.range(at: 2), in: match.source) else {
                return nil
            }
            return "\(coefficientWord) \(match.source[variableRange])"
        }

        for value in 16...20 {
            result = result.replacingOccurrences(
                of: #"\b\#(value)\b"#,
                with: numberWords[value] ?? "\(value)",
                options: .regularExpression
            )
        }

        result = result
            .replacingOccurrences(of: "=", with: " equals ")
            .replacingOccurrences(of: "+", with: " plus ")
            .replacingOccurrences(of: "*", with: " times ")
            .replacingOccurrences(of: "×", with: " times ")
        result = replacingMatches(
            in: result,
            pattern: #"(?<=\s)-(?=\s)|(?<=[A-Za-z0-9])-(?=[0-9])|(?<=[0-9])-(?=[A-Za-z])"#
        ) { _ in " minus " }

        return result
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let numberWords = [
        0: "zero",
        1: "one",
        2: "two",
        3: "three",
        4: "four",
        5: "five",
        6: "six",
        7: "seven",
        8: "eight",
        9: "nine",
        10: "ten",
        11: "eleven",
        12: "twelve",
        13: "thirteen",
        14: "fourteen",
        15: "fifteen",
        16: "sixteen",
        17: "seventeen",
        18: "eighteen",
        19: "nineteen",
        20: "twenty",
    ]

    private static let denominatorWords = [
        2: (singular: "half", plural: "halves"),
        3: (singular: "third", plural: "thirds"),
        4: (singular: "fourth", plural: "fourths"),
        5: (singular: "fifth", plural: "fifths"),
        6: (singular: "sixth", plural: "sixths"),
        7: (singular: "seventh", plural: "sevenths"),
        8: (singular: "eighth", plural: "eighths"),
        9: (singular: "ninth", plural: "ninths"),
        10: (singular: "tenth", plural: "tenths"),
    ]

    private struct MatchContext {
        let match: NSTextCheckingResult
        let source: String

        func range(at index: Int) -> NSRange {
            match.range(at: index)
        }
    }

    private static func replacingMatches(
        in source: String,
        pattern: String,
        replacement: (MatchContext) -> String?
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return source
        }
        var result = source
        let matches = expression.matches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
        for match in matches.reversed() {
            let context = MatchContext(match: match, source: source)
            guard let replacement = replacement(context),
                  let range = Range(match.range, in: result) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    private static func integer(in context: MatchContext, rangeAt index: Int) -> Int? {
        guard let range = Range(context.range(at: index), in: context.source) else {
            return nil
        }
        return Int(context.source[range])
    }
}
