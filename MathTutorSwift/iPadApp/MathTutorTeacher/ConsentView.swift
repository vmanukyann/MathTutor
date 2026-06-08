import MathTutorCore
import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var appModel: AppModel
    let student: StudentProfile

    @State private var studyLogging = true
    @State private var noAnswerMode = true

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Button {
                appModel.returnHome()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Study Mode")
                    .font(.largeTitle.bold())
                Text("MathTutor will watch the work, remember patterns, and give short hints without giving final answers.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 16) {
                Toggle("Log this student's tutoring sessions", isOn: $studyLogging)
                Toggle("No-answer integrity mode", isOn: $noAnswerMode)
                    .disabled(true)
            }
            .font(.headline)

            Button {
                appModel.acceptConsent(for: student)
            } label: {
                Label("Begin Tutoring", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!studyLogging || !noAnswerMode)

            Spacer()
        }
        .padding(40)
    }
}
