import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Native extras the spec needs: IDFV, WKWebView UA, Apple attributionToken,
/// and inbound Adjust / universal links.
class GrayDevice {
  GrayDevice._();

  static const _channel = MethodChannel('com.eggboundrush.gray/bridge');
  static const _links = EventChannel('com.eggboundrush.gray/deeplinks');

  static final _pending = <String>[];
  static final _linkController = StreamController<String>.broadcast();
  static StreamSubscription<dynamic>? _subscription;
  static var _listening = false;

  static void listenForDeeplinks() {
    if (_listening) return;
    _listening = true;
    _subscription = _links.receiveBroadcastStream().listen((event) {
      final value = event?.toString().trim() ?? '';
      if (value.isEmpty) return;
      _pending.add(value);
      _linkController.add(value);
    });
  }

  static Stream<String> get deeplinks => _linkController.stream;

  /// Deep link / universal link that opened the app, if any.
  static String? takePendingDeeplink() {
    if (_pending.isEmpty) return null;
    return _pending.removeAt(0);
  }

  static Future<String> bundleId() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.packageName;
    } on Object {
      return 'com.eggboundrush.eggboundrushgame';
    }
  }

  static Future<String> idfv() async {
    if (!Platform.isIOS) return '';
    return _invoke('getIdfv');
  }

  static Future<String> userAgent() async {
    return _invoke('getUserAgent');
  }

  /// Apple Search Ads token for the `referer` field.
  static Future<String> attributionToken() async {
    if (!Platform.isIOS) return '';
    return _invoke('getAttributionToken');
  }

  static Future<void> setLandscapeAllowed(bool allowed) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('setLandscapeAllowed', allowed);
    } on Object catch (error) {
      debugPrint('[Gray] setLandscapeAllowed failed: $error');
    }
  }

  static Future<String> _invoke(String method) async {
    try {
      final value = await _channel.invokeMethod<String>(method);
      return value?.trim() ?? '';
    } on Object catch (error) {
      debugPrint('[Gray] $method failed: $error');
      return '';
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _listening = false;
  }
}
