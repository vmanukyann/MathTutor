import SwiftUI

struct ExternalStudentDisplayView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            MTBackground()

            if appModel.externalDisplay.isTeaching {
                MathOnlyDisplay(lines: appModel.externalDisplay.mathLines)
            } else {
                ExternalDisplayStandbyView()
            }
        }
    }
}

struct ExternalDisplayStandbyView: View {
    var body: some View {
        Color.clear
            .accessibilityLabel("MathTutor display ready")
    }
}

struct MathOnlyDisplay: View {
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    LaTeXMathView(latex: line, fontSize: 68)
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .accessibilityLabel(line)
                }
            }
            .padding(40)
            .background(MTTheme.notebookPaper)
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 36)
        .frame(maxWidth: 1100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Math steps")
    }
}
