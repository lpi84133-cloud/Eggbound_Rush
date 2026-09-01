import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      GrayBridge.shared.bind(messenger: controller.binaryMessenger)
    }
    if let url = connectionOptions.urlContexts.first?.url {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
    if let activity = connectionOptions.userActivities.first(
      where: { $0.activityType == NSUserActivityTypeBrowsingWeb }
    ), let url = activity.webpageURL {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
  }
}
