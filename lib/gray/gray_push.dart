import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'gray_config.dart';
import 'gray_permissions.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } on Object {
    // A missing or stale native configure must not crash the isolate.
  }
}

/// Firebase Cloud Messaging. Init runs before [runApp] so Messaging never
/// talks to a missing default app. On iOS the FCM token is requested only
/// after APNS has arrived.
class GrayPush {
  GrayPush._();

  static var _ready = false;
  static var _backgroundBound = false;

  static Future<void> configure() async {
    if (!GrayConfig.firebaseConfigured) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } on Object catch (error) {
      debugPrint('[Gray] Firebase configure skipped: $error');
    }
  }

  static void installBackgroundHandler() {
    if (_backgroundBound) return;
    _backgroundBound = true;
    if (!GrayConfig.firebaseConfigured) return;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
    } on Object catch (error) {
      debugPrint('[Gray] background handler skipped: $error');
    }
  }

  static Future<void> init() async {
    if (_ready) return;
    if (!GrayConfig.firebaseConfigured) return;
    await configure();
    if (Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      // Waits for the tracking alert to be dismissed, otherwise iOS drops one
      // of the two prompts and the user never answers it.
      await GrayPermissions.queued(
        () =>
            messaging.requestPermission(alert: true, badge: true, sound: true),
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((_) {});
      FirebaseMessaging.onMessageOpenedApp.listen((_) {});
      _ready = true;
    } on Object catch (error) {
      debugPrint('[Gray] Firebase init skipped: $error');
    }
  }

  static Future<String> token() async {
    await init();
    if (!_ready) return '';
    try {
      if (Platform.isIOS) {
        await _waitForApns();
      }
      final token = await FirebaseMessaging.instance.getToken() ?? '';
      debugPrint('[Gray] FCM token=${token.isEmpty ? '<empty>' : token}');
      return token;
    } on Object catch (error) {
      debugPrint('[Gray] FCM token failed: $error');
      return '';
    }
  }

  /// iOS will throw `apns-token-not-set` if [getToken] runs first.
  static Future<void> _waitForApns() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return;
      } on Object {
        // Token not registered yet.
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }
}
