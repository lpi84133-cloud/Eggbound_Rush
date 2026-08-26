import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/era_hatch_config.dart';
import 'nest_vault.dart';

@pragma('vm:entry-point')
Future<void> ebrBackgroundMessage(RemoteMessage _) async {}

/// Firebase Cloud Messaging + APNs plumbing for the paid-campaign path.
///
/// Same shape as HenheavenDash / EggRunnerAdventure: a tap while the shell
/// is up goes to [onDestination]; a tap that arrives before the shell is
/// mounted is stashed and consumed on the next portal mount / resume.
class EggSignalHub {
  EggSignalHub(this._vault);

  final NestVault _vault;

  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  String? _token;

  /// Set by the coordinator after a SceneDelegate cold tap so
  /// [getInitialMessage] cannot re-stash the same URL and replay it on
  /// the next clean launch.
  bool _skipInitialMessage = false;

  /// Live handler while [RoostPortal] is mounted. Null means stash instead.
  void Function(String url)? onDestination;

  void Function(String token)? onTokenChanged;

  String? get token => _token;

  void suppressInitialMessage() {
    _skipInitialMessage = true;
  }

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Subscribe FIRST — a warm-start tap (app was backgrounded) can arrive
    // while getInitialMessage is still waiting, and would otherwise be lost.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = extractUrl(message.data);
      if (url == null) return;
      _deliver(url);
    });

    if (!_skipInitialMessage) {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(milliseconds: 3700),
        onTimeout: () => null,
      );
      final initialUrl = initial == null ? null : extractUrl(initial.data);
      if (initialUrl != null) await _vault.stashPushUrl(initialUrl);
    }

    FirebaseMessaging.onBackgroundMessage(ebrBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });

    await _waitForApns();
    _token = await messaging.getToken();
  }

  void _deliver(String url) {
    // Always stash. A warm-start tap often arrives while WKWebView is still
    // backgrounded and loadRequest is dropped; resume consumes the stash.
    unawaited(_vault.stashPushUrl(url));
    onDestination?.call(url);
  }

  /// Requests notification authorization (system dialog) and returns whether
  /// the user granted at least provisional access.
  Future<bool> requestAuthorization() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
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
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            await Future.delayed(EraHatchConfig.apnsPollStep);
            continue;
          }
        }
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          _token = token;
          return token;
        }
      } catch (_) {
        // Retry — most first-launch failures are transient.
      }
      await Future.delayed(EraHatchConfig.apnsPollStep);
    }
    return _token;
  }

  Future<void> _waitForApns({int attempts = 6}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 430));
    }
  }

  /// Extract a URL from a push data payload. Custom keys can sit at the
  /// top level or inside a nested `data` / `payload` map.
  static String? extractUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in const <String>[
      'url',
      'link',
      'target',
      'deeplink',
      'deep_link',
    ]) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in const <String>['data', 'payload']) {
      final nested = data[container];
      if (nested is Map) {
        final found = extractUrl(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  static void log(String message) {
    assert(() { debugPrint('[EBR.signal] $message'); return true; }());
  }
}
