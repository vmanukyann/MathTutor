import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

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
    }
}
