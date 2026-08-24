import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Measures whether this install arrived from a paid AppsFlyer OneLink campaign
/// (non-organic) or from direct App Store discovery (organic).
///
/// Deliberately read-only: it loads no URLs, changes no navigation and never
/// blocks start-up. Call [start] once from [main] as fire-and-forget — the
/// method never throws and runs entirely after the first frame.
class AttributionService {
  AttributionService._();

  static const _devKey = 'xs4DyQ7XEjgnvoWyCwDsGX';

  /// Numeric Apple App Store ID for this app (found in App Store Connect →
  /// App Information → Apple ID). Replace before submitting to App Store.
  static const _appId = 'YOUR_APP_STORE_ID';

  static AppsflyerSdk? _sdk;

  /// True when AppsFlyer classifies this install as organic (user found the
  /// app themselves); false for non-organic (arrived via a paid campaign);
  /// null while the classification is still pending.
  static bool? _isOrganic;
  static bool? get isOrganic => _isOrganic;

  /// Initialises the attribution pipeline after the first rendered frame.
  ///
  /// Order of operations:
  ///   1. Wait for the first frame so the app is visible before any dialog.
  ///   2. Request ATT authorisation on iOS 14+ (skipped if already answered).
  ///   3. Initialise the SDK and register the conversion-data callback.
  static Future<void> start() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _requestTrackingIfNeeded();

      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: _devKey,
          appId: _appId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 5,
        ),
      );
      _sdk = sdk;

      sdk.onInstallConversionData(_onConversionData);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: false,
      );
    } catch (error) {
      assert(() {
        debugPrint('[Attribution] init failed: $error');
        return true;
      }());
    }
  }

  static Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  /// AppsFlyer delivers the install classification here.
  /// [af_status] is "Organic" for direct App Store installs or "Non-organic"
  /// when the user arrived through a paid OneLink campaign.
  static void _onConversionData(dynamic raw) {
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final inner = map['payload'];
    final data = inner is Map ? Map<String, dynamic>.from(inner) : map;

    final afStatus = (data['af_status'] ?? '').toString();
    if (afStatus.isNotEmpty) {
      _isOrganic = afStatus.toLowerCase() == 'organic';
    }

    assert(() {
      final mediaSource = data['media_source'] ?? '—';
      debugPrint(
        '[Attribution] af_status=$afStatus  media_source=$mediaSource',
      );
      return true;
    }());
  }

  /// The AppsFlyer UID for this device, or null if the SDK has not yet
  /// initialised or the lookup fails.
  static Future<String?> appsFlyerUID() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }
}
