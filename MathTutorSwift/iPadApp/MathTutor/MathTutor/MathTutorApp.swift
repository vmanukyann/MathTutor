import SwiftUI

@main
struct MathTutorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()
    #if DEBUG
    @State private var didStartTtsDiagnostic = false
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.startExternalDisplaySupport()
                    #if DEBUG
                    guard !didStartTtsDiagnostic,
                          ProcessInfo.processInfo.arguments.contains(
                              "--run-elevenlabs-tts-diagnostic"
                          ) else {
                        return
                    }
                    didStartTtsDiagnostic = true
                    appModel.voiceTutor.runElevenLabsTtsDiagnostic()
                    #endif
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appModel.refreshExternalDisplaySupport()
                    }
                }
        }
    }
}
