import 'dart:async';

/// iOS shows one system alert at a time. A second prompt raised while another
/// is on screen is dropped silently, and the user never gets to answer it — so
/// everything that can prompt goes through this queue and waits its turn.
///
/// Order follows enqueue order. Tracking consent is requested first because
/// Adjust holds the install session open until it arrives.
class GrayPermissions {
  GrayPermissions._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> queued<T>(Future<T> Function() request) {
    final result = _tail.then((_) => request());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
