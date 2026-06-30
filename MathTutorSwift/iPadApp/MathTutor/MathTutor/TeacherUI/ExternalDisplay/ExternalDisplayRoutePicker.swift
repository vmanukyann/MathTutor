import AVKit
import SwiftUI

struct ExternalDisplayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = FullSizeRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        picker.backgroundColor = .clear
        picker.accessibilityLabel = "Choose AirPlay TV"
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        (picker as? FullSizeRoutePickerView)?.prepareSystemButton()
    }
}

private final class FullSizeRoutePickerView: AVRoutePickerView {
    override func layoutSubviews() {
        super.layoutSubviews()
        prepareSystemButton()
    }

    func prepareSystemButton() {
        guard let button = routeButton(in: self) else { return }
        button.frame = bounds
        button.accessibilityLabel = "Choose AirPlay TV"
        button.accessibilityHint = "Shows Apple's AirPlay device list"
    }

    private func routeButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton {
            return button
        }
        for subview in view.subviews {
            if let button = routeButton(in: subview) {
                return button
            }
        }
        return nil
    }
}

struct ExternalDisplayRouteButton: View {
    var isConnected: Bool
    var onShowInstructions: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                HStack(spacing: 7) {
                    Image(systemName: isConnected ? "airplayvideo.circle.fill" : "airplayvideo")
                        .font(.title3.weight(.semibold))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("AirPlay")
                            .font(.callout.weight(.semibold))
                        Text(isConnected ? "TV connected" : "Choose TV")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isConnected ? MTTheme.labGreen : MTTheme.secondaryInk)
                    }
                }
                .foregroundStyle(isConnected ? MTTheme.labGreen : MTTheme.graphiteInk)
                .allowsHitTesting(false)

                ExternalDisplayRoutePicker()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 120, height: 52)
            .background(MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(isConnected ? MTTheme.labGreen : MTTheme.gridLine, lineWidth: 1)
                    .allowsHitTesting(false)
            }

            Button(action: onShowInstructions) {
                Image(systemName: "info.circle")
                    .frame(width: 36, height: 52)
            }
            .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
            .accessibilityLabel("TV display instructions")
        }
    }
}

struct ExternalDisplayStatusIcon: View {
    var isConnected: Bool

    var body: some View {
        Image(systemName: isConnected ? "rectangle.on.rectangle" : "rectangle.on.rectangle.slash")
            .font(.headline.weight(.semibold))
            .foregroundStyle(isConnected ? MTTheme.labGreen : MTTheme.disabledGray)
            .frame(width: 38, height: 38)
            .background(MTTheme.notebookPaper.opacity(0.92), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                    .stroke(isConnected ? MTTheme.labGreen.opacity(0.55) : MTTheme.gridLine, lineWidth: 1)
            }
            .accessibilityLabel(isConnected ? "External display connected" : "External display not connected")
    }
}
