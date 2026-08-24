import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/era_hatch_config.dart';

/// Firebase Cloud Messaging + APNs plumbing for the paid-campaign path.
///
/// Owns the FCM token life-cycle: waits for APNs registration, polls until a
/// token is available, and exposes token refresh events so the coordinator
/// can re-POST the config endpoint with the fresh token.
class EggSignalHub {
  EggSignalHub();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  StreamController<String>? _tokenRefreshController;
  StreamSubscription<String>? _tokenSubscription;
  StreamController<String>? _openedUrlController;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Stream<String> get tokenRefresh {
    _tokenRefreshController ??= StreamController<String>.broadcast();
    _tokenSubscription ??= _fcm.onTokenRefresh.listen((token) {
      _tokenRefreshController?.add(token);
    });
    return _tokenRefreshController!.stream;
  }

  Stream<String> get onOpenedUrl {
    _openedUrlController ??= StreamController<String>.broadcast();
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final url = _extractUrl(msg.data);
      if (url != null) _openedUrlController?.add(url);
    });
    return _openedUrlController!.stream;
  }

  /// Requests notification authorization (system dialog) and returns whether
  /// the user granted at least provisional access.
  Future<bool> requestAuthorization() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Try to obtain an FCM token. Returns null if APNs never registers within
  /// the poll window (Simulator, no capability, denied permission, offline).
  Future<String?> awaitToken() async {
    for (var attempt = 0; attempt < EraHatchConfig.apnsPollCount; attempt++) {
      try {
        if (Platform.isIOS) {
          final apns = await _fcm.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            await Future.delayed(EraHatchConfig.apnsPollStep);
            continue;
          }
        }
        final token = await _fcm.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {
        // Retry — most first-launch failures are transient.
      }
      await Future.delayed(EraHatchConfig.apnsPollStep);
    }
    return null;
  }

  /// Extract a URL from a push data payload. Push messages can carry the
  /// destination under several conventional key names — check all of them
  /// so back-end changes don't silently break routing.
  static String? _extractUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    const keys = <String>['url', 'link', 'target', 'deeplink', 'deep_link'];
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshController?.close();
    await _openedUrlController?.close();
  }

  static void log(String message) {
    assert(() { debugPrint('[EBR.signal] $message'); return true; }());
  }
}
