import AdServices
import Flutter
import UIKit
import WebKit

/// Native extras for the gray routing layer: IDFV, WKWebView UA,
/// Apple Search Ads attributionToken, inbound links, orientation.
final class GrayBridge: NSObject, FlutterStreamHandler {
  static let shared = GrayBridge()

  static var allowLandscape = false

  private let methodName = "com.eggboundrush.gray/bridge"
  private let eventName = "com.eggboundrush.gray/deeplinks"

  private var events: FlutterEventSink?
  private var pendingLinks: [String] = []
  private var bound = false

  func bind(messenger: FlutterBinaryMessenger) {
    if bound { return }
    bound = true

    let methods = FlutterMethodChannel(name: methodName, binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }

    let links = FlutterEventChannel(name: eventName, binaryMessenger: messenger)
    links.setStreamHandler(self)
  }

  func emitDeeplink(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    if let events {
      events(trimmed)
    } else {
      pendingLinks.append(trimmed)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    pendingLinks.forEach { events($0) }
    pendingLinks.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    events = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getIdfv":
      result(UIDevice.current.identifierForVendor?.uuidString ?? "")
    case "getUserAgent":
      result(Self.webKitUserAgent())
    case "getAttributionToken":
      result(Self.fetchAppleSearchAdsToken() ?? "")
    case "setLandscapeAllowed":
      GrayBridge.allowLandscape = (call.arguments as? Bool) ?? false
      Self.refreshSupportedOrientations()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// UIKit caches the orientations a window supports, so flipping
  /// `allowLandscape` has no effect until something asks for a re-evaluation.
  /// Without this the WebView stays locked to whatever the game was using.
  private static func refreshSupportedOrientations() {
    DispatchQueue.main.async {
      guard
        let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first
      else { return }

      let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController

      if #available(iOS 16.0, *) {
        root?.setNeedsUpdateOfSupportedInterfaceOrientations()
        let mask: UIInterfaceOrientationMask =
          allowLandscape ? .allButUpsideDown : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
      } else {
        UIViewController.attemptRotationToDeviceOrientation()
      }
    }
  }

  /// WKWebView / system UA, as required by the spec.
  private static func webKitUserAgent() -> String {
    let view = WKWebView(frame: .zero)
    if let agent = view.value(forKey: "userAgent") as? String, !agent.isEmpty {
      return agent
    }
    let version = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
    return "Mozilla/5.0 (iPhone; CPU iPhone OS \(version) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
  }

  /// Example from the spec: AdServices `AAAttribution.attributionToken()`.
  private static func fetchAppleSearchAdsToken() -> String? {
    guard #available(iOS 14.3, *) else { return nil }
    do {
      return try AAAttribution.attributionToken()
    } catch {
      print("Failed to get AA attribution token:", error)
      return nil
    }
  }
}
