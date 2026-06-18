import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var appModel: AppModel
    let student: StudentProfile

    @State private var studyLogging = true
    @State private var noAnswerMode = true

    var body: some View {
        NavigationStack {
            ZStack {
                MTBackground()

                VStack {
                    HStack {
                        VoiceControlIndicator(snapshot: appModel.voiceRecognizer.snapshot)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(24)

                VStack(spacing: 24) {
                    Spacer()

                    Text(student.name)
                        .font(.system(size: 48, weight: .semibold, design: .serif))
                        .foregroundStyle(MTTheme.chalkboardGreen)
                        .minimumScaleFactor(0.72)

                    VStack(spacing: 10) {
                        ConsentToggleRow(
                            symbol: "externaldrive.badge.checkmark",
                            title: "Study log",
                            isOn: $studyLogging
                        )

                        ConsentToggleRow(
                            symbol: "lock.shield",
                            title: "No answers",
                            isOn: $noAnswerMode
                        )
                        .disabled(true)
                    }
                    .frame(maxWidth: 440)

                    HStack(spacing: 12) {
                        Button {
                            appModel.returnHome()
                        } label: {
                            Image(systemName: "return")
                        }
                        .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
                        .accessibilityLabel("Back to students")

                        Button {
                            appModel.acceptConsent(for: student)
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }
                        .buttonStyle(MTIconButton(tint: MTTheme.notebookPaper))
                        .background(MTTheme.chalkboardGreen, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
                        .disabled(!studyLogging || !noAnswerMode)
                        .opacity(!studyLogging || !noAnswerMode ? 0.45 : 1)
                        .accessibilityLabel("Begin tutoring")
                    }

                    Spacer()
                }
                .padding(MTTheme.pagePadding)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: appModel.voiceRecognizer.commandEventID) { _, _ in
                handleVoiceCommand()
            }
        }
    }

    private func handleVoiceCommand() {
        guard let command = appModel.voiceRecognizer.lastRecognizedCommand else { return }
        let action = appModel.voiceRouter.route(
            command,
            in: VoiceRouteContext(
                location: .consent,
                sessionStatus: nil,
                canEnterTeachMode: false,
                holderControlsActive: false
            )
        )
        appModel.voiceRecognizer.recordRoutedAction(action.displayName)

        if action == .startSession, studyLogging, noAnswerMode {
            appModel.acceptConsent(for: student)
        }
    }
}

private struct ConsentToggleRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(MTTheme.ink)
        }
        .toggleStyle(.switch)
        .padding(14)
        .background(MTTheme.notebookPaper.opacity(0.82), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .accessibilityLabel(title)
    }
}
