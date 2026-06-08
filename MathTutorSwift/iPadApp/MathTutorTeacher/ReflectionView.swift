import MathTutorCore
import SwiftUI

struct ReflectionView: View {
    @EnvironmentObject private var appModel: AppModel
    let session: TutoringSession

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Session Reflection")
                .font(.largeTitle.bold())

            HStack(spacing: 18) {
                metric("Checks", "\(session.events.count)", "viewfinder")
                metric("Mistakes", "\(session.mistakeCount)", "exclamationmark.triangle")
                metric("Self-corrections", "\(session.selfCorrectionCount)", "checkmark.circle")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Most recent hints")
                    .font(.title2.bold())
                ForEach(session.events.suffix(4)) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.observation.misconceptionType.displayName)
                            .font(.headline)
                        Text(event.observation.hint)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()

            Button {
                appModel.returnHome()
            } label: {
                Label("Back to Students", systemImage: "person.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
