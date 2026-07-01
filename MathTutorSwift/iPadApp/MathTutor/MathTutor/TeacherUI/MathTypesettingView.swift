import SwiftMath
import SwiftUI

struct LaTeXMathView: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat = 32
    var color: UIColor = UIColor(MTTheme.deepBlackGreen)
    var alignment: MTTextAlignment = .center
    var isBold = false

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.backgroundColor = .clear
        label.labelMode = .display
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        let expression = LaTeXNormalizer.expression(latex)
        label.latex = isBold ? "\\mathbf{\(expression)}" : expression
        label.font = MTFontManager().font(withName: MathFont.latinModernFont.rawValue, size: fontSize)
        label.textColor = color
        label.textAlignment = alignment
        label.labelMode = .display
        label.displayErrorInline = false
        label.contentInsets = MTEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        label.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MTMathUILabel,
        context: Context
    ) -> CGSize? {
        var intrinsic = uiView.intrinsicContentSize
        let proposedWidth = max(proposal.width ?? intrinsic.width, 1)
        if intrinsic.width > proposedWidth {
            let fittedSize = max(12, fontSize * proposedWidth / intrinsic.width)
            uiView.font = MTFontManager().font(
                withName: MathFont.latinModernFont.rawValue,
                size: fittedSize
            )
            intrinsic = uiView.intrinsicContentSize
        }
        return CGSize(
            width: proposedWidth,
            height: max(intrinsic.height, 44)
        )
    }
}

struct TutorHintView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(LaTeXNormalizer.segments(in: content).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let text):
                    Text(text)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(MTTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                case .math(let latex):
                    LaTeXMathView(latex: latex, fontSize: 21, alignment: .left)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(MTTheme.notebookPaper)
                        .overlay {
                            RoundedRectangle(cornerRadius: MTTheme.compactRadius)
                                .stroke(MTTheme.gridLine, lineWidth: 1)
                        }
                        .accessibilityLabel(latex)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MathStepCard: View {
    let number: Int
    let latex: String
    var fontSize: CGFloat = 34
    var isProminent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step \(number)")
                .font(isProminent ? .title3.weight(.bold) : .caption.weight(.semibold))
                .foregroundStyle(isProminent ? MTTheme.chalkboardGreen : MTTheme.labGreen)

            LaTeXMathView(
                latex: latex,
                fontSize: fontSize,
                isBold: isProminent
            )
                .frame(maxWidth: .infinity, minHeight: 54)
                .accessibilityLabel("Step \(number): \(latex)")
        }
        .padding(isProminent ? 22 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MTTheme.notebookPaper)
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                .stroke(
                    isProminent ? MTTheme.labGreen.opacity(0.72) : MTTheme.gridLine,
                    lineWidth: isProminent ? 2 : 1
                )
        }
    }
}

enum TutorContentSegment: Equatable {
    case prose(String)
    case math(String)
}

enum LaTeXNormalizer {
    static func expression(_ source: String) -> String {
        var result = repairJSONEscapes(in: source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```latex", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```tex", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")

        let wrappers = [("\\(", "\\)"), ("\\[", "\\]"), ("$$", "$$"), ("$", "$")]

        for (opening, closing) in wrappers
        where result.hasPrefix(opening) && result.hasSuffix(closing) {
            result.removeFirst(opening.count)
            result.removeLast(closing.count)
            break
        }

        result = result
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "+/-", with: "\\pm ")
            .replacingOccurrences(of: #"(?<!\\)\b(frac|sqrt|text|cdot|times|div|neq|leq|geq|left|right|begin|end)(?=[\{\s])"#, with: #"\\$1"#, options: .regularExpression)

        result = result
            .replacingOccurrences(of: "≠", with: "\\neq ")
            .replacingOccurrences(of: "≤", with: "\\leq ")
            .replacingOccurrences(of: "≥", with: "\\geq ")
            .replacingOccurrences(of: "·", with: "\\cdot ")
            .replacingOccurrences(of: "×", with: "\\times ")
            .replacingOccurrences(of: "÷", with: "\\div ")
            .replacingOccurrences(of: "²", with: "^{2}")
            .replacingOccurrences(of: "³", with: "^{3}")
            .replacingOccurrences(of: "→", with: "\\to ")
            .replacingOccurrences(of: "↓", with: "\\downarrow ")
            .replacingOccurrences(of: "□", with: "\\square ")

        result = result
            .replacingOccurrences(
                of: #"(?<![\\\w}])([A-Za-z0-9]+)\s*/\s*([A-Za-z0-9]+)(?![\w{])"#,
                with: #"\\frac{$1}{$2}"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\^([A-Za-z0-9])(?![A-Za-z0-9}])"#,
                with: #"^{$1}"#,
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s*=\s*"#, with: " = ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isMathOnlyExpression(_ source: String) -> Bool {
        let normalized = expression(source)
        let forbiddenWords = [
            "something",
            "unknown",
            "answer",
            "value",
            "placeholder",
            "undefined",
            "variable",
            "number",
            "term",
            "solution",
            "result"
        ]

        let lowercased = normalized.lowercased()
        guard !forbiddenWords.contains(where: {
            lowercased.range(of: "\\b\($0)\\b", options: .regularExpression) != nil
        }) else {
            return false
        }

        guard !lowercased.contains("\\text"),
              !lowercased.contains("\\mathrm"),
              !lowercased.contains("\\operatorname"),
              !normalized.contains("..."),
              !normalized.contains(","),
              normalized.range(
                of: #"^\s*[A-Za-z]\s*=\s*(?![A-Za-z](?:\s|$))"#,
                options: .regularExpression
              ) == nil,
              bracesAreBalanced(in: normalized) else {
            return false
        }

        let withoutCommands = normalized.replacingOccurrences(
            of: #"\\[A-Za-z]+"#,
            with: "",
            options: .regularExpression
        )
        return withoutCommands.range(of: #"[A-Za-z]{2,}"#, options: .regularExpression) == nil
    }

    private static func bracesAreBalanced(in source: String) -> Bool {
        var depth = 0
        for character in source {
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth < 0 {
                    return false
                }
            }
        }
        return depth == 0
    }

    private static func repairJSONEscapes(in source: String) -> String {
        source
            .replacingOccurrences(of: "\u{000C}rac", with: "\\frac")
            .replacingOccurrences(of: "\u{0008}egin", with: "\\begin")
            .replacingOccurrences(of: "\t ext", with: "\\text")
            .replacingOccurrences(of: "\text", with: "\\text")
            .replacingOccurrences(of: "\times", with: "\\times")
            .replacingOccurrences(of: "\right", with: "\\right")
    }

    static func segments(in source: String) -> [TutorContentSegment] {
        let pattern = #"\\\((.+?)\\\)|\\\[(.+?)\\\]|\$\$(.+?)\$\$|\$(.+?)\$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.prose(source)]
        }

        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        var segments: [TutorContentSegment] = []
        var cursor = source.startIndex

        for match in regex.matches(in: source, range: range) {
            guard let matchRange = Range(match.range, in: source) else { continue }
            appendProse(String(source[cursor..<matchRange.lowerBound]), to: &segments)

            for captureIndex in 1..<match.numberOfRanges {
                guard let captureRange = Range(match.range(at: captureIndex), in: source) else { continue }
                segments.append(.math(String(source[captureRange])))
                break
            }
            cursor = matchRange.upperBound
        }

        appendProse(String(source[cursor...]), to: &segments)
        return segments.isEmpty ? [.prose(source)] : segments
    }

    private static func appendProse(_ text: String, to segments: inout [TutorContentSegment]) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            segments.append(.prose(cleaned))
        }
    }
}
