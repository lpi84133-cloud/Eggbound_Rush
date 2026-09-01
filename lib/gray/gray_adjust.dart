import 'dart:async';
import 'dart:convert';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_deeplink.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'gray_config.dart';
import 'gray_device.dart';
import 'gray_permissions.dart';

class AdjustSnapshot {
  const AdjustSnapshot({
    required this.adid,
    required this.oneLink,
    required this.naming,
  });

  final String adid;
  final String oneLink;
  final String naming;
}

enum _FirstSignal { deeplink, attribution }

/// Starts Adjust as early as possible and waits for the first of:
/// deep link or attribution. Debug builds report to the sandbox, which is
/// what Adjust's Testing Console reads when verifying attribution.
class GrayAdjust {
  GrayAdjust._();

  static var _started = false;
  static final _deeplink = Completer<String>();
  static final _attribution = Completer<AdjustAttribution>();

  static Future<void> start() async {
    if (_started || !GrayConfig.adjustConfigured) return;
    _started = true;

    final config = AdjustConfig(
      GrayConfig.adjustAppToken,
      kDebugMode ? AdjustEnvironment.sandbox : AdjustEnvironment.production,
    );
    config.logLevel = kDebugMode
        ? AdjustLogLevel.verbose
        : AdjustLogLevel.suppress;
    // Must stay below adjustSignalTimeout, otherwise Adjust is still holding
    // the install session when we give up waiting for attribution.
    config.attConsentWaitingInterval = 15;
    config.isAdServicesEnabled = true;
    config.isIdfvReadingEnabled = true;
    config.isDeferredDeeplinkOpeningEnabled = false;
    config.deferredDeeplinkCallback = _onDeeplink;
    config.directDeeplinkCallback = _onDeeplink;
    config.attributionCallback = _onAttribution;

    try {
      Adjust.initSdk(config);
    } on Object catch (error) {
      debugPrint('[Gray] Adjust init failed: $error');
    }

    GrayDevice.deeplinks.listen((uri) {
      handleDeeplink(uri);
      _onDeeplink(uri);
    });

    final pending = GrayDevice.takePendingDeeplink();
    if (pending != null && pending.isNotEmpty) {
      handleDeeplink(pending);
      _onDeeplink(pending);
    }

    unawaited(_requestAtt());
  }

  static void _onDeeplink(String? uri) {
    final value = uri?.trim() ?? '';
    if (value.isEmpty || _deeplink.isCompleted) return;
    _deeplink.complete(value);
  }

  static void _onAttribution(AdjustAttribution attribution) {
    if (_attribution.isCompleted) return;
    _attribution.complete(attribution);
  }

  static Future<AdjustSnapshot> collect() async {
    await start();

    var oneLink = '';
    var naming = '';
    _FirstSignal? first;

    final pending = GrayDevice.takePendingDeeplink();
    if (pending != null && pending.isNotEmpty) {
      handleDeeplink(pending);
      _onDeeplink(pending);
    }

    try {
      first = await Future.any<_FirstSignal>([
        _deeplink.future.then((_) => _FirstSignal.deeplink),
        _attribution.future.then((_) => _FirstSignal.attribution),
      ]).timeout(GrayConfig.adjustSignalTimeout);
    } on TimeoutException {
      if (_deeplink.isCompleted) {
        first = _FirstSignal.deeplink;
      } else if (_attribution.isCompleted) {
        first = _FirstSignal.attribution;
      }
    }

    if (first == _FirstSignal.deeplink) {
      oneLink = await _deeplink.future;
    } else if (first == _FirstSignal.attribution) {
      naming = _namingOf(await _attribution.future);
    } else {
      try {
        // Unlike getAdid there is no timeout variant, and a stalled SDK would
        // otherwise hold the launch flow open forever.
        final attribution = await Adjust.getAttribution().timeout(
          const Duration(seconds: 5),
        );
        naming = _namingOf(attribution);
      } on Object {
        // Attribution may not be ready yet.
      }
    }

    final adid = await Adjust.getAdidWithTimeout(4000) ?? '';
    debugPrint('[Gray] adjust adid=$adid idfa=${await _idfa()}');

    if (first == _FirstSignal.deeplink) {
      return AdjustSnapshot(adid: adid, oneLink: oneLink, naming: '');
    }
    if (first == _FirstSignal.attribution) {
      return AdjustSnapshot(adid: adid, oneLink: '', naming: naming);
    }
    if (oneLink.isNotEmpty) {
      return AdjustSnapshot(adid: adid, oneLink: oneLink, naming: '');
    }
    return AdjustSnapshot(adid: adid, oneLink: '', naming: naming);
  }

  static Future<void> _requestAtt() {
    // Enqueued during start(), before anything else can ask for a permission,
    // so the tracking alert is the one the user sees first.
    return GrayPermissions.queued(() async {
      try {
        var status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // iOS silently drops the prompt while the app is still launching.
          await _waitUntilForeground();
          status = await AppTrackingTransparency.requestTrackingAuthorization();
        }
        debugPrint('[Gray] ATT status=$status');
      } on Object catch (error) {
        debugPrint('[Gray] ATT failed: $error');
      }
    });
  }

  static Future<void> _waitUntilForeground() async {
    final binding = WidgetsBinding.instance;
    await binding.waitUntilFirstFrameRasterized;
    for (var attempt = 0; attempt < 40; attempt++) {
      if (binding.lifecycleState == AppLifecycleState.resumed) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Only for the debug log: the value Adjust's "Forget device" form expects.
  static Future<String> _idfa() async {
    try {
      return await Adjust.getIdfa() ?? '';
    } on Object {
      return '';
    }
  }

  static void handleDeeplink(String uri) {
    try {
      Adjust.processDeeplink(AdjustDeeplink(uri));
    } on Object catch (error) {
      debugPrint('[Gray] processDeeplink failed: $error');
    }
  }

  static String _namingOf(AdjustAttribution attribution) {
    final json = attribution.jsonResponse?.trim();
    if (json != null && json.isNotEmpty) return json;
    final map = <String, String>{};
    void put(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) map[key] = trimmed;
    }

    put('trackerToken', attribution.trackerToken);
    put('trackerName', attribution.trackerName);
    put('network', attribution.network);
    put('campaign', attribution.campaign);
    put('adgroup', attribution.adgroup);
    put('creative', attribution.creative);
    put('clickLabel', attribution.clickLabel);
    return map.isEmpty ? '' : jsonEncode(map);
  }
}
