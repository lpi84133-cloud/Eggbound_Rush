import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/era_hatch_config.dart';

/// Wraps the AppsFlyer SDK for the paid-campaign routing coordinator.
///
/// The SDK is initialised once and shared between the classifier
/// (`AttributionService.isOrganic`, still used by the game path) and the
/// routing pipeline, which needs the full conversion payload verbatim on
/// the config POST.
class FlightAttribution {
  FlightAttribution._();

  static final FlightAttribution instance = FlightAttribution._();

  AppsflyerSdk? _sdk;
  bool _starting = false;
  bool _attRequested = false;

  final Completer<Map<String, dynamic>> _conversion =
      Completer<Map<String, dynamic>>();
  Map<String, dynamic>? _deepLink;
  final Completer<Map<String, dynamic>?> _deepLinkOnce =
      Completer<Map<String, dynamic>?>();

  bool? _isOrganic;
  bool? get isOrganic => _isOrganic;

  /// Kick off the SDK and register the callback that unblocks the routing
  /// pipeline. Safe to call more than once — subsequent calls no-op.
  Future<void> start() async {
    if (_sdk != null || _starting) return;
    _starting = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _requestTrackingIfNeeded();

      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: EraHatchConfig.appsFlyerDevKey,
          appId: EraHatchConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 5,
        ),
      );
      _sdk = sdk;

      sdk.onInstallConversionData(_onConversionData);
      sdk.onDeepLinking(_onDeepLink);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      _log('flight_attribution.start: $error');
      if (!_conversion.isCompleted) {
        _conversion.complete(<String, dynamic>{'status': 'failure'});
      }
      if (!_deepLinkOnce.isCompleted) _deepLinkOnce.complete(null);
    } finally {
      _starting = false;
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    if (_attRequested) return;
    _attRequested = true;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await Future<void>.delayed(EraHatchConfig.attPromptDelay);
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {
      // Denied / unavailable — routing continues without the identifier.
    }
  }

  void _onConversionData(dynamic raw) {
    final flat = _flatten(raw);
    final status = (flat['af_status'] ?? '').toString();
    if (status.isNotEmpty) {
      _isOrganic = status.toLowerCase() == 'organic';
    }
    if (!_conversion.isCompleted) _conversion.complete(flat);
    _log('conversion af_status=$status media_source=${flat['media_source'] ?? '—'}');
  }

  void _onDeepLink(dynamic raw) {
    final flat = _flatten(raw);
    _deepLink = flat;
    if (!_deepLinkOnce.isCompleted) _deepLinkOnce.complete(flat);
    _log('deeplink keys=${flat.keys.toList()}');
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final inner = map['payload'] ?? map['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return map;
  }

  /// Wait for the conversion payload, with a hard ceiling. A timeout is
  /// treated as a failure to attribute — the pipeline still runs, but
  /// `af_status` is left empty so routing does not commit to a paid path.
  Future<Map<String, dynamic>> awaitConversion({Duration? timeout}) {
    final t = timeout ?? EraHatchConfig.installSignalsTimeout;
    return _conversion.future.timeout(
      t,
      onTimeout: () => <String, dynamic>{'status': 'failure'},
    );
  }

  /// Returns the deep-link payload if one arrived within [window], else null.
  Future<Map<String, dynamic>?> awaitDeepLink({Duration? window}) {
    if (_deepLink != null) return Future.value(_deepLink);
    final w = window ?? const Duration(seconds: 3);
    return _deepLinkOnce.future.timeout(w, onTimeout: () => null);
  }

  Future<String?> appsFlyerUID() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// GCD lookup fallback used by the routing pipeline when the SDK callback
  /// times out. iOS uses the numeric App Store id (not the bundle id).
  Uri buildGcdUrl(String deviceId) => Uri.parse(
        '${EraHatchConfig.gcdBase}/install_data/v5.0/'
        '${EraHatchConfig.platformStoreId}?device_id=$deviceId',
      );

  void _log(String message) {
    assert(() { debugPrint('[EBR.flight] $message'); return true; }());
  }
}
