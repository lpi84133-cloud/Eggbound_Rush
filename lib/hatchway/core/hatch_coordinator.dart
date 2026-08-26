import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/era_hatch_config.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/flight_attribution.dart';
import '../infra/hatch_exchange.dart';
import '../infra/launch_route_reader.dart';
import '../infra/nest_vault.dart';
import '../infra/reach_probe.dart';
import '../infra/roost_agent.dart';
import '../models/hatch_reply.dart';
import '../models/session_mode.dart';

/// The single decision the paid-campaign path ever makes: for this launch,
/// do we mount the native game, the partner content shell, or the offline
/// screen? Every input (attribution, config response, saved URL, network
/// state, cold-start push tap) funnels into [decide].
class HatchDestination {
  const HatchDestination._({
    required this.route,
    this.url,
    this.coldStartPush = false,
  });

  final NestRoute route;
  final String? url;
  final bool coldStartPush;

  static const HatchDestination native = HatchDestination._(route: NestRoute.native);
  static const HatchDestination offline = HatchDestination._(route: NestRoute.fresh);

  factory HatchDestination.portal(String url, {bool coldStart = false}) {
    return HatchDestination._(
      route: NestRoute.portal,
      url: url,
      coldStartPush: coldStart,
    );
  }

  bool get isPortal => route == NestRoute.portal;
  bool get isNative => route == NestRoute.native;
  bool get isOffline => route == NestRoute.fresh;
}

/// Progress reporter — the coordinator publishes weighted fractions so the
/// existing [LoadingScreen] animates a real bar.
typedef HatchProgress = void Function(double fraction, String label);

class HatchCoordinator {
  HatchCoordinator({
    required this.vault,
    required this.attribution,
    required this.probe,
    required this.exchange,
    required this.signals,
  });

  final NestVault vault;
  final FlightAttribution attribution;
  final ReachProbe probe;
  final HatchExchange exchange;
  final EggSignalHub signals;

  Future<HatchDestination>? _pending;
  int _runId = 0;

  /// [fresh] drops a stale in-flight pipeline (the one that started while
  /// the radio was down) so Retry does not wait out its timeouts.
  /// [hurry] shortens AF / token / config waits after a Nowifi restore.
  Future<HatchDestination> decide({
    HatchProgress? onProgress,
    bool fresh = false,
    bool hurry = false,
  }) {
    if (fresh) {
      _runId++;
      final id = _runId;
      final fut = _runPipeline(
        onProgress ?? _noopProgress,
        hurry: hurry,
      ).whenComplete(() {
        if (_runId == id) _pending = null;
      });
      _pending = fut;
      return fut;
    }
    return _pending ??= _runPipeline(onProgress ?? _noopProgress, hurry: hurry)
        .whenComplete(() => _pending = null);
  }

  static void _noopProgress(double fraction, String label) {}

  Future<HatchDestination> _runPipeline(
    HatchProgress report, {
    bool hurry = false,
  }) async {
    final id = _runId;
    bool stillCurrent() => id == _runId;

    report(0.02, 'Warming up');

    // 1. Cold-start push tap always wins — if the user tapped a notification
    //    while the app was killed, load that URL first.
    final coldUrl = await LaunchRouteReader.consume();
    if (coldUrl != null && coldUrl.isNotEmpty) {
      if (!stillCurrent()) return HatchDestination.offline;
      // Firebase would re-report the same tap through getInitialMessage;
      // suppress so it is not stashed and replayed on the next clean start.
      signals.suppressInitialMessage();
      await vault.writeMode(NestRoute.portal);
      await vault.consumePushUrl();
      report(1, 'Opening notification');
      _log('cold-start URL: $coldUrl');
      return HatchDestination.portal(coldUrl, coldStart: true);
    }
    report(0.08, 'Reading local state');

    final mode = await vault.readMode();
    _log('mode=$mode');

    // 2. Interface check (connectivity_plus — radio up/down, NOT DNS).
    //    First launch and returning gray both need a live link. Returning
    //    native does not: the game is fully local.
    //    Without a config answer we MUST NOT pick native vs portal.
    final hasInterface = await probe.hasAnyInterface();
    if (!hasInterface && mode != NestRoute.native) {
      report(1, 'Waiting for internet');
      return HatchDestination.offline;
    }

    // 3. Returning gray user: a pending push tap outranks the saved link.
    if (mode == NestRoute.portal) {
      report(0.25, 'Reading saved link');
      final pending = await vault.consumePushUrl();
      if (pending != null && pending.isNotEmpty) {
        if (!stillCurrent()) return HatchDestination.offline;
        report(1, 'Opening notification');
        return HatchDestination.portal(pending);
      }
      final saved = await vault.readSavedUrl();
      if (saved != null) {
        report(1, 'Opening content');
        return HatchDestination.portal(saved);
      }
      // Fall through — a returning user with no saved URL re-hits the
      // config endpoint so the server can hand us a fresh destination.
    }

    // 4. Returning organic user: usually just the game, but periodically
    //    give the server another chance to re-classify the install.
    if (mode == NestRoute.native) {
      final lastCheck = await vault.readOrganicLastCheckAt();
      final now = DateTime.now();
      final due = lastCheck == null ||
          now.difference(lastCheck).inSeconds >=
              EraHatchConfig.organicRecheckSeconds * 3600;
      if (!due) {
        report(1, 'Loading game');
        return HatchDestination.native;
      }
      // Silent recheck — never blocks the game path on the network.
      await vault.stampOrganicChecked();
    }

    // 5. Fresh or due for reclassification: run the full attribution +
    //    config pipeline. Nothing network-dependent runs before the
    //    interface check above (gray_flow_lessons.md §25).
    report(0.35, 'Warming attribution');
    await attribution.start();

    report(0.5, 'Preparing signals');
    String? pushToken = signals.token;
    if (!hurry) {
      try {
        pushToken = await signals.awaitToken().timeout(
          EraHatchConfig.installSignalsTimeout,
          onTimeout: () => signals.token,
        );
      } catch (_) {
        pushToken = signals.token;
      }
    }
    _log('push_token_ready=${pushToken != null} hurry=$hurry');

    report(0.7, 'Contacting service');
    HatchReply reply;
    while (true) {
      reply = await exchange.resolve(pushToken: pushToken, hurry: hurry);
      if (!stillCurrent()) return HatchDestination.offline;
      if (reply.granted && reply.destination != null) break;
      if (reply.reachedServer) break;
      // Transport miss. Nowifi only when the radio is actually down —
      // a live interface (OneLink restore, Wi-Fi just came back) must
      // keep trying instead of bouncing to the offline screen.
      if (!await probe.hasAnyInterface()) {
        _log('config unreachable, no interface — nowifi');
        if (mode == NestRoute.native) {
          report(1, 'Loading game');
          return HatchDestination.native;
        }
        report(1, 'Waiting for internet');
        return HatchDestination.offline;
      }
      _log('config unreachable, radio up — retrying');
      await Future<void>.delayed(EraHatchConfig.hurryConfigRetryGap);
    }
    report(0.92, 'Applying decision');
    if (!stillCurrent()) return HatchDestination.offline;

    if (reply.granted && reply.destination != null) {
      await vault.writeSavedUrl(
        reply.destination!,
        expiresAt: reply.expiresAt,
      );
      await vault.writeMode(NestRoute.portal);
      report(1, 'Opening content');
      return HatchDestination.portal(reply.destination!);
    }

    // Genuine "no URL" from the server — only now may we commit native.
    if (!stillCurrent()) return HatchDestination.offline;
    await vault.writeMode(NestRoute.native);
    report(1, 'Loading game');
    return HatchDestination.native;
  }

  void _log(String message) {
    assert(() { debugPrint('[EBR.coord] $message'); return true; }());
  }
}

/// Factory that wires the concrete singletons together. Callers only need
/// to construct this once — usually from the paid-flow root widget.
HatchCoordinator buildCoordinator() {
  final agent = RoostAgent();
  final attribution = FlightAttribution.instance;
  final vault = NestVault();
  final probe = ReachProbe();
  final exchange = HatchExchange(agent: agent, attribution: attribution);
  final signals = EggSignalHub(vault);
  return HatchCoordinator(
    vault: vault,
    attribution: attribution,
    probe: probe,
    exchange: exchange,
    signals: signals,
  );
}
