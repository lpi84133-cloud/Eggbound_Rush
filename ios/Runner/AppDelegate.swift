import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Reads the bundled plist explicitly so a missing file degrades to
  /// "no push" instead of raising at launch.
  private static func configureFirebase() {
    guard FirebaseApp.app() == nil else { return }
    guard
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let options = FirebaseOptions(contentsOfFile: path)
    else {
      NSLog("[Gray] GoogleService-Info.plist missing — push disabled")
      return
    }
    FirebaseApp.configure(options: options)
  }

  /// The implicit Flutter engine — and with it the Messaging plugin — is
  /// created inside super's `willFinishLaunching`, so Firebase has to be up
  /// before that call. Doing it in `init()` is too early: the app delegate is
  /// not installed yet and Firebase then fails to swizzle it.
  override func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Self.configureFirebase()
    return super.application(application, willFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.configureFirebase()
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    if let url = launchOptions?[.url] as? URL {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GrayBridge.shared.bind(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// Handing the token over explicitly keeps FCM working even if Firebase's
  /// delegate swizzling is unavailable, which is what caused `apns-token-not-set`.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Gray] APNS registration failed: \(error.localizedDescription)")
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    GrayBridge.shared.emitDeeplink(url.absoluteString)
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      GrayBridge.shared.emitDeeplink(url.absoluteString)
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return GrayBridge.allowLandscape ? .allButUpsideDown : .portrait
  }
}
