import SwiftUI

#if targetEnvironment(simulator)
struct ExternalDisplaySimulatorPreviewButton: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isPresented = false

    var body: some View {
        Button {
            appModel.setExternalDisplayConnected(true)
            if !appModel.externalDisplay.isTeaching {
                appModel.updateExternalTeachMode(lines: ["3(x + 2)", "= 3x + 3·2", "= 3x + 6"])
            }
            isPresented = true
        } label: {
            Image(systemName: "rectangle.on.rectangle")
        }
        .buttonStyle(MTIconButton(tint: MTTheme.labGreen))
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
