import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/boot/boot_controller.dart';
import '../../features/boot/loading_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../config/era_hatch_config.dart';
import '../core/hatch_coordinator.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/launch_route_reader.dart';
import '../infra/nest_vault.dart';
import '../infra/reach_probe.dart';
import '../models/session_mode.dart';
import 'empty_air_page.dart';
import 'feather_invitation.dart';
import 'roost_portal.dart';

/// Top-level gate for every launch. Runs the native boot pipeline and the
/// paid-campaign coordinator in parallel and mounts one of three surfaces
/// as soon as both have settled:
///
///   * `native`  → the finished game (existing onboarding + AppShell flow)
///   * `portal`  → paid-campaign WebView shell (with an optional push
///                 permission opt-in preceding it on the first entry)
///   * `offline` → the no-signal overlay on top of the same splash
///                 (Retry / Wi-Fi restore continue the bar from where
///                 it paused — never remount the loading screen)
class HatchGate extends ConsumerStatefulWidget {
  const HatchGate({super.key});

  @override
  ConsumerState<HatchGate> createState() => _HatchGateState();
}

class _HatchGateState extends ConsumerState<HatchGate>
    with WidgetsBindingObserver {
  final HatchCoordinator _coordinator = buildCoordinator();

  NestVault get _vault => _coordinator.vault;
  EggSignalHub get _signals => _coordinator.signals;

  HatchDestination? _destination;
  bool _bootReady = false;
  bool _permitDone = false;
  bool _permitNeeded = false;
  bool _pushEvaluationDone = false;
  /// Interface-down before the coordinator finishes — first launch and
  /// returning gray overlay Nowifi on top of the still-mounted splash.
  bool _offlineFast = false;
  /// Radio is up — the splash bar may climb past the ~32 % Nowifi gate.
  bool _linkUp = false;
  bool _retrying = false;
  /// Bumped on every Nowifi retry so a stale in-flight [decide] cannot
  /// re-apply "offline" after the user already restored the interface.
  int _decideGen = 0;
  /// Remounts the Nowifi overlay so Retry-without-net feels like a fresh screen.
  int _nowifiEpoch = 0;
  /// Sprint the splash bar after a live-radio Retry (32 % → 80 % quickly).
  bool _sprintFill = false;

  final ReachProbe _probe = ReachProbe();
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A tap that arrives before the WebView is mounted (splash / invite /
    // native game) must still swap this gate onto the portal URL.
    _signals.onDestination = _onPushUrl;
    unawaited(_signals.boot());

    unawaited(_detectImmediateOffline());
    _connSub = _probe.onChange.listen(_onInterface);
    unawaited(_runDecide());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_consumeNativeTap());
    }
  }

  /// Warm-start: SceneDelegate does not re-fire. Native code writes the tap
  /// URL into UserDefaults / the stash; pick it up on resume. Retry a couple
  /// of times — the write can land a beat after `resumed`.
  Future<void> _consumeNativeTap() async {
    const delays = <int>[0, 180, 420];
    for (final wait in delays) {
      if (wait > 0) {
        await Future<void>.delayed(Duration(milliseconds: wait));
      }
      if (!mounted) return;
      final native = await LaunchRouteReader.consume();
      final stashed = await _vault.consumePushUrl();
      final url = native ?? stashed;
      if (url != null && url.isNotEmpty) {
        _onPushUrl(url);
        return;
      }
    }
  }

  void _onPushUrl(String url) {
    if (!mounted || url.isEmpty) return;
    if (_destination?.isPortal == true && _destination?.url == url) return;
    setState(() {
      _destination = HatchDestination.portal(url);
      _permitNeeded = false;
      _permitDone = true;
      _pushEvaluationDone = true;
      _offlineFast = false;
      _linkUp = true;
    });
  }

  /// Radio check only (`connectivity_plus`), never DNS. First launch and
  /// returning gray overlay Nowifi immediately — the splash stays mounted
  /// underneath so the bar can resume from the paused percentage.
  Future<void> _detectImmediateOffline() async {
    try {
      final mode = await _vault.readMode();
      if (mode == NestRoute.native) {
        if (mounted) setState(() => _linkUp = true);
        return;
      }
      final online = await _probe.hasAnyInterface();
      if (!mounted || _bootReady) return;
      setState(() {
        _linkUp = online;
        _offlineFast = !online;
      });
    } catch (_) {}
  }

  void _onInterface(bool online) {
    if (!mounted || _bootReady || _retrying) return;
    if (!online) {
      if (_destination != null &&
          (_destination!.isPortal || _destination!.isNative)) {
        return;
      }
      unawaited(_markOfflineIfNeeded());
      return;
    }
    final showingNowifi = _offlineFast;
    if (!showingNowifi) return;
    unawaited(_clearNowifiAndRetry());
  }

  Future<void> _markOfflineIfNeeded() async {
    try {
      final mode = await _vault.readMode();
      if (mode == NestRoute.native) return;
    } catch (_) {}
    if (!mounted || _bootReady || _retrying) return;
    setState(() {
      _offlineFast = true;
      _linkUp = false;
    });
  }

  void _keepNowifi() {
    if (!mounted) return;
    setState(() {
      _offlineFast = true;
      _linkUp = false;
      _sprintFill = false;
      _nowifiEpoch++;
    });
  }

  Future<void> _runDecide() async {
    final gen = _decideGen;
    final dest = await _coordinator.decide();
    if (gen != _decideGen) return;
    await _applyDestination(dest);
  }

  Future<void> _applyDestination(HatchDestination dest) async {
    if (!mounted) return;
    var permit = _permitNeeded;
    if (dest.isPortal) {
      permit = await _shouldShowPermit();
    }
    if (!mounted) return;
    setState(() {
      _destination = dest;
      _pushEvaluationDone = true;
      _permitNeeded = permit;
      if (dest.isPortal || dest.isNative) {
        _offlineFast = false;
        _linkUp = true;
        _sprintFill = true;
      } else {
        // Coordinator only returns offline when the radio is down.
        _linkUp = false;
        _sprintFill = false;
        _offlineFast = true;
      }
    });
  }

  /// Retry first probes the radio. No interface → stay on Nowifi in the
  /// same frame (bar never unpauses, never climbs past the 32 % gate).
  /// Interface up → drop the stale offline pipeline, sprint the bar, and
  /// re-decide in hurry mode so we reach notify instead of sitting on 80 %.
  Future<void> _clearNowifiAndRetry() async {
    if (_retrying || _bootReady) return;
    _retrying = true;
    try {
      final online = await _probe.hasAnyInterface();
      if (!mounted) return;
      if (!online) {
        _keepNowifi();
        return;
      }

      _decideGen++;
      final gen = _decideGen;
      final existing = _destination;
      if (existing != null && (existing.isPortal || existing.isNative)) {
        setState(() {
          _offlineFast = false;
          _linkUp = true;
          _sprintFill = true;
        });
        return;
      }

      setState(() {
        _offlineFast = false;
        _linkUp = true;
        _destination = null;
        _pushEvaluationDone = false;
      });

      // SDK must be up before the restore pipeline waits for OneLink.
      unawaited(_coordinator.attribution.start());
      await Future<void>.delayed(EraHatchConfig.retryLinkSettle);
      if (gen != _decideGen || !mounted) return;
      if (!await _probe.hasAnyInterface()) {
        _keepNowifi();
        return;
      }

      final dest = await _coordinator.decide(fresh: true, hurry: true);
      if (gen != _decideGen || !mounted) return;
      await _applyDestination(dest);
    } finally {
      _retrying = false;
    }
  }

  Future<bool> _shouldShowPermit() async {
    try {
      if (await _vault.readInviteShown()) return false;
      if (await _vault.readPushOsDenied()) return false;
      final until = await _vault.readPushSnoozeUntil();
      if (until != null && DateTime.now().isBefore(until)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onBootReady() {
    if (!mounted) return;
    setState(() => _bootReady = true);
  }

  Widget _buildGameFlow() {
    final services = ref.read(bootControllerProvider).services;
    if (services == null) {
      return LoadingScreen(onReady: _onBootReady);
    }
    if (services.needsOnboarding) {
      return OnboardingScreen(
        onFinished: () async {
          await services.preferences.setOnboarded();
          if (mounted) setState(() {});
        },
      );
    }
    return const AppShell();
  }

  @override
  void dispose() {
    unawaited(_connSub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dest = _destination;
    final routed = dest != null && (dest.isPortal || dest.isNative);
    // Nowifi is radio-down only. A failed config POST while Wi-Fi is up
    // must not cover the splash — OneLink restore stays on loading.
    final wantNowifi = !_bootReady && !routed && _offlineFast;

    if (!_bootReady) {
      final servicesReady = ref.watch(bootControllerProvider).isReady;
      final launchReady = !wantNowifi &&
          dest != null &&
          _pushEvaluationDone &&
          !dest.isOffline &&
          (dest.isPortal || servicesReady);
      return Stack(
        fit: StackFit.expand,
        children: [
          LoadingScreen(
            key: const ValueKey<String>('ebr.boot.splash'),
            launchReady: launchReady,
            paused: wantNowifi,
            allowPastGate: _linkUp || dest?.isNative == true,
            sprint: _sprintFill,
            onReady: _onBootReady,
          ),
          if (wantNowifi)
            EmptyAirPage(
              key: ValueKey<int>(_nowifiEpoch),
              onRetry: () => unawaited(_clearNowifiAndRetry()),
            ),
        ],
      );
    }

    if (dest == null || !_pushEvaluationDone) {
      return LoadingScreen(
        launchReady: false,
        onReady: _onBootReady,
      );
    }

    if (dest.isNative) {
      return _buildGameFlow();
    }

    if (_permitNeeded && !_permitDone) {
      return FeatherInvitation(
        vault: _vault,
        signals: _signals,
        onDone: () {
          if (!mounted) return;
          setState(() => _permitDone = true);
        },
      );
    }

    return RoostPortal(
      key: ValueKey<String>('roost:${dest.url}'),
      url: dest.url!,
      coldStartPush: dest.coldStartPush,
      vault: _vault,
      signals: _signals,
      onPushFromGate: _onPushUrl,
    );
  }
}
