import Flutter
import UIKit
import UserNotifications

/// Captures the URL from a push notification tap while the app is fully
/// killed. The paid-campaign coordinator reads this via SharedPreferences
/// as the very first step of every launch (see LaunchRouteReader).
///
/// The UserDefaults key MUST stay in sync with `LaunchRouteReader._key` on
/// the Dart side (`ebr_launch_route`); Flutter's SharedPreferences plugin
/// adds the `flutter.` prefix on iOS.
class SceneDelegate: FlutterSceneDelegate {
  static let tapUrlKey = "flutter.ebr_launch_route"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let response = connectionOptions.notificationResponse {
      captureUrl(from: response.notification.request.content.userInfo)
    }
  }

  private func captureUrl(from userInfo: [AnyHashable: Any]) {
    guard
      let url = SceneDelegate.extractUrl(from: userInfo),
      !url.isEmpty
    else { return }
    UserDefaults.standard.set(url, forKey: SceneDelegate.tapUrlKey)
  }

  static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let keys = ["url", "link", "target", "deeplink", "deep_link"]

    func value(in container: [AnyHashable: Any]) -> String? {
      for key in keys {
        if let candidate = container[key] as? String, !candidate.isEmpty {
          return candidate
        }
      }
      return nil
    }

    if let hit = value(in: userInfo) { return hit }
    if let aps = userInfo["aps"] as? [AnyHashable: Any], let hit = value(in: aps) { return hit }
    if let data = userInfo["data"] as? [AnyHashable: Any], let hit = value(in: data) { return hit }
    if let payload = userInfo["payload"] as? [AnyHashable: Any], let hit = value(in: payload) { return hit }
    return nil
  }
}
