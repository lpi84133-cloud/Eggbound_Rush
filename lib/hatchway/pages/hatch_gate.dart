import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/boot/boot_controller.dart';
import '../../features/boot/loading_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../core/hatch_coordinator.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/nest_vault.dart';
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
///   * `offline` → the no-signal screen (Retry re-mounts a fresh gate)
class HatchGate extends ConsumerStatefulWidget {
  const HatchGate({super.key});

  @override
  ConsumerState<HatchGate> createState() => _HatchGateState();
}

class _HatchGateState extends ConsumerState<HatchGate> {
  final HatchCoordinator _coordinator = buildCoordinator();
  final NestVault _vault = NestVault();
  final EggSignalHub _signals = EggSignalHub();

  HatchDestination? _destination;
  bool _bootReady = false;
  bool _permitDone = false;
  bool _permitNeeded = false;
  bool _pushEvaluationDone = false;

  StreamSubscription<String>? _openedUrlSub;

  @override
  void initState() {
    super.initState();
    // A background-state push tap (Firebase onMessageOpenedApp path) must
    // route the user into the WebView shell with the new URL, even after
    // the coordinator has already committed a destination for this launch.
    _openedUrlSub = _signals.onOpenedUrl.listen((url) {
      if (!mounted || url.isEmpty) return;
      setState(() {
        _destination = HatchDestination.portal(url);
        _permitNeeded = false;
        _permitDone = true;
        _pushEvaluationDone = true;
      });
    });

    _coordinator.decide().then((dest) async {
      if (!mounted) return;
      if (dest.isPortal) {
        _permitNeeded = await _shouldShowPermit();
      }
      _pushEvaluationDone = true;
      if (!mounted) return;
      setState(() => _destination = dest);
    });
  }

  Future<bool> _shouldShowPermit() async {
    try {
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
      // Shouldn't happen — LoadingScreen only calls onReady after
      // services are wired up. Fall back to loading defensively.
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
    _openedUrlSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Both the boot pipeline and the routing decision must be complete
    // before we leave the loading surface. If either is still running,
    // stay on LoadingScreen — its bar tracks the boot progress and pauses
    // at 100% until the routing pipeline hands us a destination.
    if (!_bootReady || _destination == null || !_pushEvaluationDone) {
      return LoadingScreen(onReady: _onBootReady);
    }

    final dest = _destination!;

    if (dest.isOffline) {
      return EmptyAirPage(retryBuilder: (_) => const HatchGate());
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

    // Keying on the URL lets a background-push URL swap force a full
    // controller rebuild (fresh WebView, fresh `_bootstrap`) instead of
    // dangling on the previous page.
    return RoostPortal(
      key: ValueKey<String>('roost:${dest.url}'),
      url: dest.url!,
      coldStartPush: dest.coldStartPush,
      offlineBuilder: (_) => EmptyAirPage(retryBuilder: (_) => const HatchGate()),
    );
  }
}
