import AVKit
import SwiftUI

struct ExternalDisplayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = NotifyingRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .clear
        picker.activeTintColor = .clear
        picker.backgroundColor = .clear
        picker.accessibilityLabel = "Choose AirPlay display"
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = .clear
        uiView.activeTintColor = .clear
        if let picker = uiView as? NotifyingRoutePickerView {
            picker.prepareSystemButton()
        }
    }
}

private final class NotifyingRoutePickerView: AVRoutePickerView {
    override func layoutSubviews() {
        super.layoutSubviews()
        prepareSystemButton()
    }

    func prepareSystemButton() {
        guard let button = systemRouteButton(in: self) else { return }
        button.frame = bounds
        button.accessibilityLabel = "Choose AirPlay display"
        button.accessibilityHint = "Shows Apple's AirPlay device list"
    }

    private func systemRouteButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton {
            return button
        }
        for subview in view.subviews {
            if let button = systemRouteButton(in: subview) {
                return button
            }
        }
        return nil
    }
}

struct ExternalDisplayRouteButton: View {
    var isConnected: Bool
    var detail: String?

    private var statusText: String {
        if let detail {
            return detail
        }
        return isConnected ? "TV connected" : "Choose TV"
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: isConnected ? "airplayvideo.circle.fill" : "airplayvideo")
                    .font(.title3.weight(.semibold))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("AirPlay")
                        .font(.callout.weight(.semibold))
                    Text(statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isConnected ? MTTheme.labGreen : MTTheme.secondaryInk)
                }
            }
            .allowsHitTesting(false)

            ExternalDisplayRoutePicker()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(isConnected ? MTTheme.labGreen : MTTheme.graphiteInk)
        .frame(width: 138, height: 52)
        .background(MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                .stroke(isConnected ? MTTheme.labGreen : MTTheme.gridLine, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(isConnected ? "AirPlay display connected" : "Choose AirPlay display")
        .accessibilityHint("Shows Apple's AirPlay device list")
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
