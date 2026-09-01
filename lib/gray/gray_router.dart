import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gray_adjust.dart';
import 'gray_api.dart';
import 'gray_connectivity.dart';
import 'gray_device.dart';
import 'gray_params.dart';
import 'gray_push.dart';
import 'gray_storage.dart';

enum GrayKind { pending, webview, stub }

@immutable
class GrayDecision {
  const GrayDecision._(this.kind, {this.url, this.label = ''});

  const GrayDecision.pending({String label = 'Starting'})
    : this._(GrayKind.pending, label: label);

  const GrayDecision.webview(String url) : this._(GrayKind.webview, url: url);

  const GrayDecision.stub() : this._(GrayKind.stub);

  final GrayKind kind;
  final String? url;
  final String label;
}

/// Launch flow from the spec:
/// 1. network
/// 2. cached user → jump to 5
/// 3. collect params
/// 4. handle API
/// 5. WebView or native stub
class GrayRouter extends Notifier<GrayDecision> {
  /// FCM waits behind the tracking prompt, then for its own prompt and the
  /// APNS token, so this budget has to cover two user decisions.
  static const _pushLimit = Duration(seconds: 40);

  /// Outer bound for [GrayAdjust.collect], which already paces itself with
  /// [GrayConfig.adjustSignalTimeout].
  static const _adjustLimit = Duration(seconds: 35);

  var _started = false;

  @override
  GrayDecision build() {
    Future<void>.microtask(resolve);
    return const GrayDecision.pending(label: 'Checking connection');
  }

  Future<void> resolve() async {
    if (_started) return;
    _started = true;

    state = const GrayDecision.pending(label: 'Checking connection');
    final online = await const GrayConnectivity().hasNetwork();

    final prefs = await SharedPreferences.getInstance();
    final storage = GrayStorage(prefs);

    // Cached decision skips a new request (step 2 → 5).
    final cachedUrl = storage.finalUrl;
    if (cachedUrl != null) {
      state = GrayDecision.webview(cachedUrl);
      return;
    }
    if (storage.blockUser) {
      state = const GrayDecision.stub();
      return;
    }

    // No internet and no cache → stub, retry on the next launch.
    if (!online) {
      state = const GrayDecision.stub();
      return;
    }

    state = const GrayDecision.pending(label: 'Preparing');
    final params = await _collectParams();

    state = const GrayDecision.pending(label: 'Opening');
    final result = await GrayApi().resolve(params);

    switch (result.outcome) {
      case GrayApiOutcome.webview:
        final url = result.url!;
        await storage.saveFinalUrl(url);
        debugPrint('[Gray] decision=webview url=$url');
        state = GrayDecision.webview(url);
      case GrayApiOutcome.block:
        await storage.saveBlockUser();
        debugPrint('[Gray] decision=block (no url in response)');
        state = const GrayDecision.stub();
      case GrayApiOutcome.failed:
        debugPrint('[Gray] decision=stub (request failed, retry next launch)');
        state = const GrayDecision.stub();
    }
  }

  /// The flow must always end at a WebView or the stub, so a stalled platform
  /// channel or SDK degrades to an empty field instead of an endless splash.
  static Future<T> _orDefault<T>(
    Future<T> future,
    T fallback, {
    Duration limit = const Duration(seconds: 10),
  }) async {
    try {
      return await future.timeout(limit);
    } on Object catch (error) {
      debugPrint('[Gray] param unavailable: $error');
      return fallback;
    }
  }

  Future<GrayParams> _collectParams() async {
    const empty = AdjustSnapshot(adid: '', oneLink: '', naming: '');
    final bundleId = _orDefault(GrayDevice.bundleId(), '');
    final idfv = _orDefault(GrayDevice.idfv(), '');
    final userAgent = _orDefault(GrayDevice.userAgent(), '');
    final referer = _orDefault(GrayDevice.attributionToken(), '');
    final push = _orDefault(GrayPush.token(), '', limit: _pushLimit);
    final adjust = _orDefault(GrayAdjust.collect(), empty, limit: _adjustLimit);

    final results = await Future.wait<Object>([
      bundleId,
      idfv,
      userAgent,
      referer,
      push,
      adjust,
    ]);

    final snapshot = results[5] as AdjustSnapshot;
    debugPrint(
      '[Gray] params appId=${results[0]} oneLink=${snapshot.oneLink} '
      'naming=${snapshot.naming}',
    );
    return GrayParams(
      appId: results[0] as String,
      pushToken: results[4] as String,
      userAgent: results[2] as String,
      deviceID: snapshot.adid,
      adId: results[1] as String,
      oneLink: snapshot.oneLink,
      naming: snapshot.naming,
      referer: results[3] as String,
    );
  }
}

final grayRouterProvider = NotifierProvider<GrayRouter, GrayDecision>(
  GrayRouter.new,
);
