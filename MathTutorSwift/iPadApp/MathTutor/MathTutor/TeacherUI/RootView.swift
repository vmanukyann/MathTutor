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
                LiveTutorSessionView(student: student)
            case .reflection(let session):
                ReflectionView(session: session)
            case .admin:
                AdminReviewView()
            }
        }
        .animation(.smooth(duration: 0.32), value: routeKey)
    }

    private var routeKey: String {
        switch appModel.route {
        case .studentPicker: "studentPicker"
        case .consent(let student): "consent-\(student.id)"
        case .liveSession(let student): "live-\(student.id)"
        case .reflection(let session): "reflection-\(session.id)"
        case .admin: "admin"
        }
    }
}
