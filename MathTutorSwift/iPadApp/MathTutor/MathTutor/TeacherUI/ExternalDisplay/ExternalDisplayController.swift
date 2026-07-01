import UIKit

@MainActor
final class ExternalDisplayController {
    private weak var appModel: AppModel?
    private var notificationObservers: [NSObjectProtocol] = []
    private var pendingDisconnect: Task<Void, Never>?

    func start(appModel: AppModel) {
        guard self.appModel == nil else { return }
        self.appModel = appModel

        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshExternalDisplay()
                }
            },
            center.addObserver(
                forName: UIScene.didDisconnectNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshExternalDisplay()
                }
            }
        ]

        refreshExternalDisplay()
    }

    deinit {
        pendingDisconnect?.cancel()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refreshExternalDisplay() {
        guard let appModel else { return }
        let hasExternalScene = UIApplication.shared.connectedScenes.contains { scene in
            scene.session.role.mtIsExternalDisplay && scene.activationState != .unattached
        }
        if hasExternalScene {
            print("MathTutorDisplay external scene connected")
            pendingDisconnect?.cancel()
            pendingDisconnect = nil
            appModel.setExternalDisplayConnected(true)
            return
        }

        pendingDisconnect?.cancel()
        pendingDisconnect = Task { @MainActor [weak self, weak appModel] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, let appModel else { return }
            let stillDisconnected = !UIApplication.shared.connectedScenes.contains { scene in
                scene.session.role.mtIsExternalDisplay && scene.activationState != .unattached
            }
            if stillDisconnected {
                print("MathTutorDisplay external scene disconnected")
                appModel.setExternalDisplayConnected(false)
            }
            self.pendingDisconnect = nil
        }
    }
}
