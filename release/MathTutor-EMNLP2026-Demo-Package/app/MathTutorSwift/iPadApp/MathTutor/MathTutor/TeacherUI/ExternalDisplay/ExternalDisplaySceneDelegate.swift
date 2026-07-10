import SwiftUI
import UIKit

@MainActor
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    private static var connectedWindows: [ObjectIdentifier: UIWindow] = [:]

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        if let appModel = AppModel.shared {
            Self.bind(window, to: appModel)
            appModel.setExternalDisplayConnected(true)
            print("mathtutor_airplay external_scene_created")
        } else {
            window.rootViewController = UIHostingController(rootView: ExternalDisplayStandbyView())
        }
        window.isHidden = false
        self.window = window
        Self.connectedWindows[ObjectIdentifier(window)] = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let window {
            Self.connectedWindows.removeValue(forKey: ObjectIdentifier(window))
        }
        window = nil
        AppModel.shared?.externalDisplayController.refreshExternalDisplay()
    }

    static func bindExistingWindows(to appModel: AppModel) {
        for window in connectedWindows.values {
            bind(window, to: appModel)
            print("mathtutor_airplay external_scene_reused")
        }
        appModel.externalDisplayController.refreshExternalDisplay()
    }

    private static func bind(_ window: UIWindow, to appModel: AppModel) {
        window.rootViewController = UIHostingController(
            rootView: ExternalStudentDisplayView()
                .environmentObject(appModel)
        )
    }
}

extension UISceneSession.Role {
    var mtIsExternalDisplay: Bool {
        self == .windowExternalDisplayNonInteractive
            || rawValue == "UIWindowSceneSessionRoleExternalDisplay"
    }
}
