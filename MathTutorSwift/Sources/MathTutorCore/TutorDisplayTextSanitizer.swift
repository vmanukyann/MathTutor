import Foundation

public enum TutorDisplayTextSanitizer {
    public static let fallbackHint =
        "Check the square root step carefully, then try the next line again."
    public static let fallbackAction =
        "Redo only the square root step before continuing."

    public static func clean(_ source: String) -> String {
        var result = source
        while result.contains("\\\\") {
            result = result.replacingOccurrences(of: "\\\\", with: "\\")
        }

        result = result
            .replacingOccurrences(of: "\\,", with: "")
            .replacingOccurrences(of: "\\(", with: "")
            .replacingOccurrences(of: "\\)", with: "")
            .replacingOccurrences(of: "\\[", with: "")
            .replacingOccurrences(of: "\\]", with: "")
            .replacingOccurrences(of: "+-", with: "±")
            .replacingOccurrences(
                of: #"±\s*sqrt\(([^)]+)\)"#,
                with: "±√$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"sqrt\(([^)]+)\)"#,
                with: "√$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\\(?:dfrac|tfrac|frac)\{([^{}]+)\}\{([^{}]+)\}"#,
                with: "$1/$2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\\sqrt\{([^{}]+)\}"#,
                with: "√$1",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\cdot", with: "·")
            .replacingOccurrences(of: "\\times", with: "×")
            .replacingOccurrences(of: "\\div", with: "÷")
            .replacingOccurrences(of: "\\neq", with: "≠")
            .replacingOccurrences(of: "\\leq", with: "≤")
            .replacingOccurrences(of: "\\geq", with: "≥")
            .replacingOccurrences(of: "\\pm", with: "±")
            .replacingOccurrences(
                of: #"\b([A-Za-z])\s*-\s*([0-9]+)\)\^"#,
                with: "($1 - $2)^",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\\[A-Za-z]+"#,
                with: "",
                options: .regularExpression
            )

        result = removeUnmatchedClosingParentheses(from: result)
            .replacingOccurrences(of: #"\s*=\s*"#, with: " = ", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?<=[A-Za-z0-9\)])-(?=[0-9\(])|(?<=[0-9\)])-(?=[A-Za-z0-9\(])"#,
                with: " - ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b([A-Za-z]+)(?:\s+\1\b)+"#,
                with: "$1",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func validated(_ source: String, fallback: String) -> String {
        let cleaned = clean(source)
        guard isSafe(cleaned), !containsForbiddenPlaceholder(source) else {
            let raw = source.replacingOccurrences(of: "\n", with: " ")
            print("mathtutor_text_sanitizer rejected_text=\(raw)")
            return fallback
        }
        return cleaned
    }

    public static func isSafe(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        return !source.isEmpty
            && !source.contains("\\")
            && !lowercased.contains("that value")
            && !lowercased.contains("marked expression")
            && !lowercased.contains("marked value")
            && !lowercased.contains("placeholder")
            && !lowercased.contains("sqrt(")
    }

    private static func containsForbiddenPlaceholder(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        return lowercased.contains("that value")
            || lowercased.contains("marked expression")
            || lowercased.contains("marked value")
            || lowercased.contains("placeholder")
    }

    private static func removeUnmatchedClosingParentheses(from source: String) -> String {
        var depth = 0
        var result = ""
        for character in source {
            if character == "(" {
                depth += 1
                result.append(character)
            } else if character == ")" {
                if depth > 0 {
                    depth -= 1
                    result.append(character)
                }
            } else {
                result.append(character)
            }
        }
        return result
    }
}
