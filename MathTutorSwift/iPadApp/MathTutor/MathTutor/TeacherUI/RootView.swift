import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch appModel.route {
            case .studentPicker:
                StudentPickerView()
            case .consent(let student):
                ConsentView(student: student)
            case .liveSession(let student):
                LiveTutorSessionView(
                    student: student,
                    standController: appModel.standController
                )
            case .reflection(let session):
                ReflectionView(session: session)
            case .admin:
                AdminReviewView()
            }
        }
        .task {
            await appModel.voiceRecognizer.ensureListening()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await appModel.voiceRecognizer.ensureListening()
                }
            case .background:
                appModel.voiceRecognizer.stopListening()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: appModel.voiceRecognizer.commandEventID) { _, _ in
            guard appModel.voiceRecognizer.lastRecognizedCommand == .emergencyStop else { return }
            appModel.standController.send(.stop)
            appModel.voiceRecognizer.recordRoutedAction("Emergency stop")
        }
    }
}
