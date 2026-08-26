import 'dart:async';
import 'dart:convert';
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
  Future<void>? _startFuture;

  /// Kick off the SDK and register the callback that unblocks the routing
  /// pipeline. Safe to call more than once — in-flight work is awaited,
  /// not abandoned (a second caller used to return while `_starting`
  /// was true, which made conversion wait time out empty).
  Future<void> start() {
    if (_sdk != null) return Future<void>.value();
    return _startFuture ??= _openSdk();
  }

  Future<void> _openSdk() async {
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
      sdk.onAppOpenAttribution(_onAppOpenAttribution);
      sdk.onDeepLinking(_onDeepLink);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      _log('flight_attribution.start: $error');
      _startFuture = null;
      if (!_conversion.isCompleted) {
        _conversion.complete(<String, dynamic>{'status': 'failure'});
      }
      if (!_deepLinkOnce.isCompleted) _deepLinkOnce.complete(null);
    }
  }

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _installRefined;

  final Completer<Map<String, dynamic>> _conversion =
      Completer<Map<String, dynamic>>();
  final Completer<Map<String, dynamic>?> _deepLinkOnce =
      Completer<Map<String, dynamic>?>();

  bool? _isOrganic;
  bool? get isOrganic => _isOrganic;
  bool _attRequested = false;

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
    final status = (flat['status'] ?? '').toString().toLowerCase();
    final afStatus = (flat['af_status'] ?? '').toString();

    // The SDK reports {status: 'failure', data: 'Request failed'} when it
    // cannot reach its own servers. Merging that as attribution would poison
    // the config body — treat it as an empty install callback instead.
    final broke = status == 'failure' ||
        (afStatus.isEmpty && flat.containsKey('status'));

    if (broke) {
      _install = <String, dynamic>{};
    } else {
      _install = flat;
      if (afStatus.isNotEmpty) {
        _isOrganic = afStatus.toLowerCase() == 'organic';
      }
    }
    _log(
      'conversion af_status=$afStatus '
      'media_source=${flat['media_source'] ?? '—'} broke=$broke',
    );

    // Release the pipeline immediately so the config POST is not blocked by
    // the background refinement below.
    if (!_conversion.isCompleted) {
      _conversion.complete(_install ?? <String, dynamic>{});
    }

    // A paid install is regularly reported as Organic on the very first
    // callback — AppsFlyer's server needs a moment to associate the click.
    // Kick off a background refinement so callers that wait a bit longer
    // (see [awaitRefinedAttribution]) get the corrected payload.
    if (!broke && afStatus.toLowerCase() == 'organic') {
      _installRefined = _refineOrganic();
    }
  }

  Future<void> _refineOrganic() async {
    try {
      await Future<void>.delayed(
        Duration(seconds: EraHatchConfig.organicRecheckSeconds),
      );
      final looked = await _lookupInstall();
      if (looked == null) return;
      final refinedStatus = (looked['af_status'] ?? '').toString();
      if (refinedStatus.isEmpty) return;
      _install = looked;
      _isOrganic = refinedStatus.toLowerCase() == 'organic';
      _log('refined af_status=$refinedStatus '
          'media_source=${looked['media_source'] ?? '—'}');
    } catch (error) {
      _log('refine failed: $error');
    }
  }

  /// Optional second-stage await used by the routing pipeline: after the
  /// initial callback releases [awaitConversion], callers can wait a bounded
  /// window for the organic → non-organic re-classification to arrive.
  Future<void> awaitRefinedAttribution({Duration? window}) async {
    final refined = _installRefined;
    if (refined == null) return;
    final w = window ??
        Duration(seconds: EraHatchConfig.organicRecheckSeconds + 4);
    try {
      await refined.timeout(w);
    } on TimeoutException {
      // Refinement is best-effort — pipeline continues with the initial data.
    }
  }

  void _onAppOpenAttribution(dynamic raw) {
    final flat = _flatten(raw);
    if (flat.isNotEmpty) _reopen = flat;
    _log('reopen keys=${flat.keys.toList()}');
  }

  void _onDeepLink(dynamic raw) {
    Map<String, dynamic> extracted = <String, dynamic>{};
    if (raw is DeepLinkResult) {
      // The SDK hands back a typed object; the useful payload is on
      // `deepLink.clickEvent`. Everything else (status, error) is diagnostic.
      final event = raw.deepLink?.clickEvent;
      if (event != null) {
        extracted = Map<String, dynamic>.from(event);
      }
      _log('deeplink status=${raw.status.toShortString()} '
          'error=${raw.error?.toShortString() ?? '—'}');
    } else {
      // Older SDKs and some platform channels deliver a raw map — keep the
      // fallback so we do not silently drop attribution.
      extracted = _flatten(raw);
    }
    if (extracted.isNotEmpty) _deepLink = extracted;
    if (!_deepLinkOnce.isCompleted) {
      _deepLinkOnce.complete(extracted.isEmpty ? null : extracted);
    }
    _log('deeplink keys=${extracted.keys.toList()}');
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final inner = map['payload'] ?? map['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return map;
  }

  /// Retries attribution over the AppsFlyer GCD lookup API. iOS uses the
  /// numeric App Store id — the bundle id returns empty data.
  Future<Map<String, dynamic>?> _lookupInstall() async {
    final uid = await appsFlyerUID();
    if (uid == null || uid.isEmpty) return null;
    try {
      final base = EraHatchConfig.gcdBase;
      final target = Uri.parse(
        '$base/install_data/v5.0/${EraHatchConfig.iosStoreId}'
        '?device_id=$uid',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final req = await client.getUrl(target);
        req.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${EraHatchConfig.appsFlyerDevKey}',
        );
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final resp = await req.close().timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) return null;
        final text =
            await resp.transform(utf8.decoder).join().timeout(
                  const Duration(seconds: 6),
                );
        if (text.isEmpty) return null;
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return null;
      } finally {
        client.close(force: true);
      }
    } catch (error) {
      _log('lookup failed: $error');
      return null;
    }
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

  /// The full merged attribution snapshot: install callback + re-open +
  /// deep link. Callers layer their own fields on top. Everything the SDK
  /// delivered is passed verbatim to the config endpoint.
  Map<String, dynamic> currentAttribution() {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    _reopen?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _deepLink?.forEach((k, v) => body.putIfAbsent(k, () => v));
    return body;
  }

  Future<String?> appsFlyerUID() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// GCD lookup URL exposed for callers that want to reuse the endpoint
  /// (kept for backwards compatibility with earlier gray-flow drops).
  Uri buildGcdUrl(String deviceId) => Uri.parse(
        '${EraHatchConfig.gcdBase}/install_data/v5.0/'
        '${EraHatchConfig.iosStoreId}?device_id=$deviceId',
      );

  void _log(String message) {
    assert(() { debugPrint('[EBR.flight] $message'); return true; }());
  }
}
