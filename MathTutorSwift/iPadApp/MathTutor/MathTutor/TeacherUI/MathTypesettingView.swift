import SwiftMath
import SwiftUI

struct LaTeXMathView: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat = 32
    var color: UIColor = UIColor(MTTheme.deepBlackGreen)
    var alignment: MTTextAlignment = .center

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.backgroundColor = .clear
        label.labelMode = .display
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        label.latex = LaTeXNormalizer.expression(latex)
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
            let fittedSize = max(18, fontSize * proposedWidth / intrinsic.width)
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
                    LaTeXMathView(latex: latex, fontSize: 25, alignment: .left)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(latex)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .replacingOccurrences(of: #"(?<!\\)\b(frac|sqrt|text|cdot|times|div|neq|leq|geq|left|right|begin|end)(?=[\{\s])"#, with: #"\\$1"#, options: .regularExpression)

        return result
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
