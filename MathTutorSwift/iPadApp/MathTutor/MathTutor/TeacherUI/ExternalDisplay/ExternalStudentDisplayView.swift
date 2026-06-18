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
        VStack(spacing: 18) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(MTTheme.labGreen)
                .accessibilityHidden(true)

            Text("Ready")
                .font(.system(size: 44, weight: .semibold, design: .serif))
                .foregroundStyle(MTTheme.deepBlackGreen)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("External display ready")
    }
}

struct MathOnlyDisplay: View {
    let lines: [String]

    var body: some View {
        VStack(spacing: 32) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 76, weight: .semibold, design: .serif))
                    .foregroundStyle(MTTheme.deepBlackGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.34)
                    .accessibilityLabel(line)
            }
        }
        .padding(.horizontal, 56)
        .frame(maxWidth: 1100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Math steps")
    }
}
