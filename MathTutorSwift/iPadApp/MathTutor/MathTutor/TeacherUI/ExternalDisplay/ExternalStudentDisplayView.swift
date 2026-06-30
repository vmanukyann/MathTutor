import SwiftUI

struct ExternalStudentDisplayView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            MTTheme.notebookPaper
                .ignoresSafeArea()

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
        if lines == ["SCAN AGAIN"] {
            Text("SCAN AGAIN")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(MTTheme.deepBlackGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Scan again")
        } else {
            GeometryReader { proxy in
                let stepCount = max(lines.count, 1)
                let gap: CGFloat = 18
                let verticalPadding: CGFloat = 34
                let usableHeight = proxy.size.height
                    - (verticalPadding * 2)
                    - (gap * CGFloat(max(stepCount - 1, 0)))
                let cardHeight = max(112, usableHeight / CGFloat(stepCount))
                let formulaSize = min(78, max(46, cardHeight * 0.36))

                VStack(spacing: gap) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        MathStepCard(
                            number: index + 1,
                            latex: line,
                            fontSize: formulaSize,
                            isProminent: true
                        )
                        .frame(height: cardHeight)
                    }
                }
                .padding(.horizontal, max(36, proxy.size.width * 0.035))
                .padding(.vertical, verticalPadding)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .center
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Math steps")
        }
    }
}
