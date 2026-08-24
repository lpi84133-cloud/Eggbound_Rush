import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Answers a single question: does this device have working internet right
/// now? Uses `connectivity_plus` as a cheap first check and a DNS lookup as
/// the truth (a phone can report Wi-Fi while the network drops requests).
class ReachProbe {
  ReachProbe();

  final Connectivity _connectivity = Connectivity();

  /// `true` only if the OS reports at least one interface AND a probe
  /// hostname resolves. Never blocks longer than a few seconds.
  Future<bool> hasLiveInternet() async {
    if (!await hasAnyInterface()) return false;
    return _probeDns();
  }

  Future<bool> hasAnyInterface() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any(
        (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
      );
    } catch (_) {
      return true; // Fail open — WebView will surface the real error.
    }
  }

  /// Emits transitions between offline / online. First event is the current
  /// state at subscription time (helps callers react immediately).
  Stream<bool> get onChange async* {
    yield await hasAnyInterface();
    yield* _connectivity.onConnectivityChanged.map((results) {
      return results.any(
        (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
      );
    });
  }

  Future<bool> _probeDns() async {
    // Non-standard probe host rotated away from the sibling default
    // (cloudflare.com in the sibling family).
    const candidates = <String>['apple.com', 'gstatic.com'];
    for (final host in candidates) {
      try {
        final result = await InternetAddress.lookup(host).timeout(
          const Duration(seconds: 3),
        );
        if (result.isNotEmpty) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }
}
