import 'package:shared_preferences/shared_preferences.dart';

/// Reads (and consumes) the URL captured by iOS SceneDelegate when the user
/// taps a push while the app is fully killed.
///
/// SceneDelegate writes into `NSUserDefaults.standard` under the key below.
/// Flutter's shared_preferences maps to the same store; the runtime prefix
/// `flutter.` is added by the plugin, so the Swift side writes
/// `flutter.ebr_launch_route` while Dart reads `ebr_launch_route`.
///
/// The URL is one-shot: `consume` clears it after reading so a later relaunch
/// falls back to the normal config flow.
class LaunchRouteReader {
  const LaunchRouteReader._();

  static const String _key = 'ebr_launch_route';

  static Future<String?> consume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_key);
      if (url == null || url.isEmpty) return null;
      await prefs.remove(_key);
      return url;
    } catch (_) {
      return null;
    }
  }
}
