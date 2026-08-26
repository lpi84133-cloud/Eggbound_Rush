import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ask the system to register for remote notifications. Firebase's swizzled
    // path picks up the resulting APNs token — without this call the messaging
    // token never appears and every notifications feature stalls.
    application.registerForRemoteNotifications()
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Wrap the notification-center delegate *after* Flutter/Firebase have
    // claimed it, so a backgrounded tap is persisted without dropping the
    // plugin callback.
    EbrTapCatcher.shared.install()
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Extra capture if we are still the UNUserNotificationCenter delegate
  /// (no scene wrap yet). Always call super so Firebase still sees the tap.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    SceneDelegate.persistTap(from: response.notification.request.content.userInfo)
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }
}
