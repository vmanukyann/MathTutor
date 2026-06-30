import SwiftUI

#if targetEnvironment(simulator)
struct ExternalDisplaySimulatorPreviewButton: View {
    @EnvironmentObject private var appModel: AppModel
    let previewLines: [String]
    @State private var isPresented = false

    init(previewLines: [String] = ["Demo board", "Put work under camera", "Then tap Check Work"]) {
        self.previewLines = previewLines
    }

    var body: some View {
        Button {
            appModel.setExternalDisplayConnected(true)
            if !appModel.externalDisplay.isTeaching {
                appModel.updateExternalTeachMode(lines: previewLines)
            }
            isPresented = true
        } label: {
            Label("Preview", systemImage: "rectangle.on.rectangle")
        }
        .buttonStyle(MTSecondaryButton())
        .accessibilityLabel("Preview external display")
        .fullScreenCover(isPresented: $isPresented) {
            ExternalDisplaySimulatorPreview()
                .environmentObject(appModel)
                .onDisappear {
                    appModel.setExternalDisplayConnected(false)
                }
        }
    }
}

private struct ExternalDisplaySimulatorPreview: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ExternalStudentDisplayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
            .accessibilityLabel("Close external display preview")
            .padding(18)
        }
    }
}
#endif
