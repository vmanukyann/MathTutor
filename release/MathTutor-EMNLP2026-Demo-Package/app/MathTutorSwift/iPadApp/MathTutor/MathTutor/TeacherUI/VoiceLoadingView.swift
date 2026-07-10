import SwiftUI

struct VoiceLoadingView: View {
    @EnvironmentObject private var appModel: AppModel

    let student: StudentProfile

    var body: some View {
        ZStack {
            MTBackground()

            VStack(spacing: 22) {
                ProgressView()
                    .controlSize(.large)
                    .tint(MTTheme.labGreen)

                Text("Preparing MathTutor")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(MTTheme.chalkboardGreen)

                Text(appModel.voiceTutor.voiceStatus)
                    .font(.body.weight(.medium))
                    .foregroundStyle(MTTheme.secondaryInk)
                    .multilineTextAlignment(.center)

                Text("The first setup can take a few minutes. It only needs to download once on this iPad.")
                    .font(.callout)
                    .foregroundStyle(MTTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)

                Button("Back") {
                    appModel.returnHome()
                }
                .buttonStyle(.bordered)
                .tint(MTTheme.chalkboardGreen)
            }
            .padding(36)
            .background(
                MTTheme.notebookPaper.opacity(0.96),
                in: RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
            .padding(28)
        }
        .onAppear {
            continueWhenReady()
        }
        .onChange(of: appModel.voiceTutor.isReady) { _, _ in
            continueWhenReady()
        }
    }

    private func continueWhenReady() {
        guard appModel.voiceTutor.isReady else { return }
        appModel.beginPreparedSession(for: student)
    }
}
