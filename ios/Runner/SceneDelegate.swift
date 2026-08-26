import Flutter
import UIKit
import UserNotifications

/// Captures the URL from a push notification tap.
///
/// Cold start: `willConnectTo` has `connectionOptions.notificationResponse`.
/// Warm start (app backgrounded, scene already connected): that callback
/// does NOT fire. iOS delivers the tap to `UNUserNotificationCenter`'s
/// delegate instead. `EbrTapCatcher` wraps whoever currently owns that
/// delegate (Flutter / Firebase) so we persist the URL without stealing
/// the plugin callback.
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
      SceneDelegate.persistTap(from: response.notification.request.content.userInfo)
    }
    EbrTapCatcher.shared.install()
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    super.sceneWillEnterForeground(scene)
    EbrTapCatcher.shared.install()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    EbrTapCatcher.shared.install()
  }

  static func persistTap(from userInfo: [AnyHashable: Any]) {
    guard let destination = extractUrl(from: userInfo) else { return }
    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: tapUrlKey)
    defaults.synchronize()
    #if DEBUG
    NSLog("[EBR.ROUTE] persisted tap destination")
    #endif
  }

  static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let keys = ["url", "link", "target", "deeplink", "deep_link"]

    func value(in container: [AnyHashable: Any]) -> String? {
      for key in keys {
        guard let candidate = container[key] as? String else { continue }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let hit = value(in: userInfo) { return hit }
    if let aps = userInfo["aps"] as? [AnyHashable: Any], let hit = value(in: aps) {
      return hit
    }
    for container in ["data", "payload"] {
      if let nested = userInfo[container] as? [AnyHashable: Any],
         let hit = value(in: nested) {
        return hit
      }
    }
    return nil
  }
}

/// Forwards notification-center callbacks to the previous delegate (Firebase /
/// Flutter) after writing the tap URL. Installed *after* `super.application`
/// so we wrap the plugin instead of replacing it.
final class EbrTapCatcher: NSObject, UNUserNotificationCenterDelegate {
  static let shared = EbrTapCatcher()

  private weak var inner: UNUserNotificationCenterDelegate?

  func install() {
    let center = UNUserNotificationCenter.current()
    let current = center.delegate
    if current === self { return }
    inner = current
    center.delegate = self
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    SceneDelegate.persistTap(from: response.notification.request.content.userInfo)
    if let inner = inner {
      inner.userNotificationCenter?(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
    } else {
      completionHandler()
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let inner = inner {
      inner.userNotificationCenter?(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
    } else {
      completionHandler([.banner, .sound, .badge])
    }
  }
}
