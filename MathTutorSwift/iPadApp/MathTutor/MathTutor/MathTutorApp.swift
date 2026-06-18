import SwiftUI

@main
struct MathTutorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.startExternalDisplaySupport()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appModel.refreshExternalDisplaySupport()
                    }
                }
        }
    }
}
