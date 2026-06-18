import AVKit
import SwiftUI

struct ExternalDisplayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = UIColor(MTTheme.graphiteInk)
        picker.activeTintColor = UIColor(MTTheme.labGreen)
        picker.backgroundColor = .clear
        picker.accessibilityLabel = "Choose AirPlay display"
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(MTTheme.graphiteInk)
        uiView.activeTintColor = UIColor(MTTheme.labGreen)
    }
}

struct ExternalDisplayRouteButton: View {
    var isConnected: Bool

    var body: some View {
        ExternalDisplayRoutePicker()
            .frame(width: 48, height: 48)
            .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(isConnected ? MTTheme.labGreen : MTTheme.gridLine, lineWidth: 1)
            }
            .accessibilityLabel(isConnected ? "AirPlay display connected" : "Choose AirPlay display")
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
