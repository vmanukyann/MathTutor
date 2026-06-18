import UIKit

@MainActor
final class ExternalDisplayController {
    private weak var appModel: AppModel?
    private var notificationObservers: [NSObjectProtocol] = []

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
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refreshExternalDisplay() {
        guard let appModel else { return }
        let hasExternalScene = UIApplication.shared.connectedScenes.contains { scene in
            scene.session.role.mtIsExternalDisplay && scene.activationState != .unattached
        }
        appModel.setExternalDisplayConnected(hasExternalScene)
    }
}
