import AVKit
import SwiftUI

struct AirPlayChoiceView: View {
    @EnvironmentObject private var appModel: AppModel

    let student: StudentProfile

    var body: some View {
        ZStack {
            MTBackground()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: appModel.externalDisplay.isConnected ? "airplayvideo.circle.fill" : "airplayvideo")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(appModel.externalDisplay.isConnected ? MTTheme.labGreen : MTTheme.chalkboardGreen)

                    Text("Connect display?")
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(MTTheme.chalkboardGreen)

                    Text("Use AirPlay if you want the teacher display on a TV or external screen.")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(MTTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)

                    Text(appModel.externalDisplay.isConnected ? "Display connected." : "No display connected yet.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appModel.externalDisplay.isConnected ? MTTheme.labGreen : MTTheme.secondaryInk)
                        .padding(.top, 4)
                }

                VStack(spacing: 12) {
                    AirPlayRoutePickerButton()
                        .frame(width: 260, height: 52)
                        .background(MTTheme.chalkboardGreen, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
                        .overlay {
                            Label("Use AirPlay", systemImage: "airplayvideo")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .allowsHitTesting(false)
                        }
                        .accessibilityLabel("Use AirPlay")

                    Button {
                        print("mathtutor_airplay continue_without_airplay")
                        appModel.continueAfterAirPlayChoice(for: student)
                    } label: {
                        Label("Continue without AirPlay", systemImage: "arrow.right")
                            .frame(width: 260)
                    }
                    .buttonStyle(MTLabeledControlButton(tint: MTTheme.graphiteInk))

                    Button {
                        appModel.continueAfterAirPlayChoice(for: student)
                    } label: {
                        Text(appModel.externalDisplay.isConnected ? "Continue" : "I’ll connect later")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MTTheme.secondaryInk)
                }

                Spacer()
            }
            .padding(MTTheme.pagePadding)
        }
        .onAppear {
            print("mathtutor_airplay screen_shown")
            appModel.refreshExternalDisplaySupport()
        }
        .onChange(of: appModel.externalDisplay.isConnected) { _, connected in
            print(
                connected
                    ? "mathtutor_airplay external_screen_connected"
                    : "mathtutor_airplay external_screen_disconnected"
            )
        }
    }
}

private struct AirPlayRoutePickerButton: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.delegate = context.coordinator
        picker.prioritizesVideoDevices = true
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}

    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            print("mathtutor_airplay route_picker_opened")
        }
    }
}
