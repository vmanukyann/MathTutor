import SwiftUI

struct ReflectionView: View {
    @EnvironmentObject private var appModel: AppModel
    let session: TutoringSession

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 16) {
                    SessionCount(title: "Checks", value: session.events.count, symbol: "viewfinder")
                    SessionCount(title: "Mistakes", value: session.mistakeCount, symbol: "exclamationmark.triangle")
                    SessionCount(title: "Corrections", value: session.selfCorrectionCount, symbol: "checkmark")
                }

                if !session.events.isEmpty {
                    SessionHistoryLog(events: session.events)
                }

                Button {
                    appModel.returnHome()
                } label: {
                    Label("Home", systemImage: "house.fill")
                        .frame(minWidth: 180)
                }
                .buttonStyle(MTLabeledControlButton(fill: MTTheme.chalkboardGreen, isFilled: true))
                .accessibilityLabel("Return home")
            }
            .frame(maxWidth: 760)
            .padding(.vertical, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MTTheme.pagePadding)
        .background(MTBackground())
    }
}

private struct SessionHistoryLog: View {
    let events: [TutorEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Check \(index + 1)", systemImage: event.observation.mistakeDetected ? "exclamationmark.triangle" : "checkmark")
                            .font(.headline)
                            .foregroundStyle(event.observation.mistakeDetected ? MTTheme.errorRust : MTTheme.labGreen)
                        Spacer()
                        Text(event.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(MTTheme.secondaryInk)
                    }

                    Text("Mistake")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MTTheme.secondaryInk)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.observation.mistakeDetected ? event.observation.misconceptionType.displayName : "No clear mistake")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MTTheme.graphiteInk)

                        if !event.observation.workSummary.isEmpty {
                            TutorHintView(content: event.observation.workSummary)
                        }
                    }

                    Text("Tutor guidance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MTTheme.secondaryInk)

                    TutorHintView(content: event.tutorMessage ?? event.observation.hint)

                    if event.studentSelfCorrected {
                        Label("Corrected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MTTheme.labGreen)
                    }
                }
                .padding(16)

                if index < events.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MTTheme.notebookPaper)
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SessionCount: View {
    let title: String
    let value: Int
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(MTTheme.labGreen)
            Text("\(value)")
                .font(.system(size: 46, weight: .semibold, design: .serif))
                .foregroundStyle(MTTheme.deepBlackGreen)
            Text(title)
                .font(.headline)
                .foregroundStyle(MTTheme.graphiteInk)
        }
        .frame(width: 190, height: 170)
        .background(MTTheme.notebookPaper)
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
