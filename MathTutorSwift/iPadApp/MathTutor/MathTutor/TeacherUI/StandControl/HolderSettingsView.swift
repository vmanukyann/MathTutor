import SwiftUI

struct HolderSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var standController: StandController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 14) {
                            MTStatusPill(
                                title: standController.connectionMode.displayName,
                                symbol: standController.connectionMode == .simulated ? "switch.2" : "wifi",
                                tint: standController.connectionMode == .simulated ? MTTheme.accent : MTTheme.success
                            )

                            Text("Holder Control")
                                .font(.system(size: 44, weight: .semibold, design: .serif))
                                .foregroundStyle(MTTheme.chalkboardGreen)
                                .minimumScaleFactor(0.75)

                            Text("Prototype the future motorized iPad holder without requiring hardware. Leave the URL blank for simulated mode.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        MTMetricCard(
                            title: "Current Mode",
                            value: standController.state.modeDescription,
                            symbol: modeSymbol,
                            tint: modeTint
                        )
                        MTMetricCard(
                            title: "Last Command",
                            value: standController.state.lastCommand?.displayName ?? "None",
                            symbol: "clock.arrow.circlepath",
                            tint: MTTheme.accent
                        )
                        MTMetricCard(
                            title: "Angle",
                            value: "\(Int(standController.state.simulatedAngleDegrees)) deg",
                            symbol: "angle",
                            tint: MTTheme.warning
                        )
                    }

                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 16) {
                            MTSectionHeader(
                                title: "Connection",
                                subtitle: "Use simulated mode for the app prototype. Add an ESP32 URL later when hardware exists."
                            )

                            TextField("http://math-tutor-stand.local", text: $standController.baseURLString)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(14)
                                .background(MTTheme.notebookPaper.opacity(0.82), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                                        .stroke(MTTheme.gridLine, lineWidth: 1)
                                }

                            if let lastError = standController.state.lastError {
                                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                                    .font(.callout)
                                    .foregroundStyle(MTTheme.warning)
                            }
                        }
                    }

                    MTGlassPanel(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 16) {
                            MTSectionHeader(
                                title: "Test Commands",
                                subtitle: "Test movement slowly before any iPad is mounted."
                            )

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                                commandButton(.observeMode)
                                commandButton(.teachMode)
                                commandButton(.pitchDownToPaper)
                                commandButton(.pitchUpToStudent)
                                commandButton(.center)
                                stopButton
                            }
                        }
                    }

                    VoiceDebugPanel(recognizer: appModel.voiceRecognizer)
                }
                .padding(MTTheme.pagePadding)
            }
            .background(MTBackground())
            .navigationTitle("Holder")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func commandButton(_ command: StandCommand) -> some View {
        Group {
            if command == .teachMode {
                Button {
                    standController.send(command)
                } label: {
                    Label(command.displayName, systemImage: command.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MTPrimaryButton())
            } else {
                Button {
                    standController.send(command)
                } label: {
                    Label(command.displayName, systemImage: command.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MTSecondaryButton())
            }
        }
        .disabled(standController.state.isMoving)
    }

    private var stopButton: some View {
        Button {
            standController.send(.stop)
        } label: {
            Label(StandCommand.stop.displayName, systemImage: StandCommand.stop.systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MTSecondaryButton())
        .foregroundStyle(MTTheme.danger)
    }

    private var modeSymbol: String {
        switch standController.state.currentMode {
        case .observe: "camera.viewfinder"
        case .teach: "rectangle.inset.filled.and.person.filled"
        case .moving: "arrow.triangle.2.circlepath"
        case .stopped: "stop.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var modeTint: Color {
        switch standController.state.currentMode {
        case .observe: MTTheme.accent
        case .teach: MTTheme.success
        case .moving: MTTheme.warning
        case .stopped: MTTheme.secondaryInk
        case .error: MTTheme.danger
        }
    }
}
