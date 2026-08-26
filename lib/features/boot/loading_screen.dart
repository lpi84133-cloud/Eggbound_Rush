import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import 'boot_controller.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({
    super.key,
    required this.onReady,
    this.launchReady = false,
    this.paused = false,
    this.allowPastGate = false,
    this.sprint = false,
  });

  final VoidCallback onReady;

  /// Set by [HatchGate] once the routing decision is in and (for the
  /// native path) game services are wired. The bar may then leave the
  /// 80 % hold and run to 100 % — never earlier.
  final bool launchReady;

  /// Freeze the painted value (Nowifi overlay). Resume continues from
  /// the same percentage instead of restarting at 0.
  final bool paused;

  /// Without a live interface the bar must not climb past the ~32 % gate.
  /// Past that only after the parent confirms the radio is up.
  final bool allowPastGate;

  /// After Nowifi → Retry with a live radio, close the remaining 32→80
  /// stretch in about a second instead of the first-launch 5.1 s clock.
  final bool sprint;

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Painted value. Climbs 0 → 0.80 on a fixed clock (~5.1 s), then waits.
  /// Only the parent flipping [LoadingScreen.launchReady] lets it finish.
  double _displayed = 0;
  bool _handedOff = false;

  /// ~5.1 s to the 80 % hold — a round five-second Duration is a
  /// portfolio fingerprint (hardening §7a / §9.7).
  static const double _hold = 0.80;
  /// Nowifi must never paint above this unless the radio is actually up.
  static const double _gate = 0.32;
  static const double _fillSeconds = 5.1;
  static const double _sprintSeconds = 1.15;
  static const double _finishSeconds = 0.28;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bootControllerProvider.notifier).start(context);
    });
  }

  @override
  void didUpdateWidget(LoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused ||
        widget.allowPastGate != oldWidget.allowPastGate ||
        widget.sprint != oldWidget.sprint) {
      _lastTick = Duration.zero;
    }
  }

  void _onTick(Duration elapsed) {
    if (widget.paused) {
      _lastTick = Duration.zero;
      return;
    }

    final delta = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // A huge delta (app resumed, overlay dismissed) must not jump the bar.
    final step = delta.clamp(0.0, 0.05);

    final finishing = widget.launchReady && _displayed >= _hold - 0.002;
    final cruise = widget.allowPastGate ? _hold : _gate;
    final target = finishing ? 1.0 : cruise;
    if (_displayed >= target) {
      if (finishing) _finish();
      return;
    }

    final rate = finishing
        ? (1.0 - _hold) / _finishSeconds
        : widget.sprint
            ? math.max(0.08, _hold - _displayed) / _sprintSeconds
            : _hold / _fillSeconds;
    final next = math.min(target, _displayed + rate * step);

    setState(() => _displayed = next);

    if (next >= 0.9995 && widget.launchReady) _finish();
  }

  Future<void> _finish() async {
    if (_handedOff) return;
    if (!widget.launchReady) return;
    _handedOff = true;
    _ticker.stop();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) widget.onReady();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final background = isLandscape
        ? 'assets/app/branding/loading_landscape.webp'
        : 'assets/app/branding/loading_portrait.webp';

    return Scaffold(
      backgroundColor: AppColors.accentSoft,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(background,
              fit: BoxFit.cover, alignment: Alignment.center),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66101C13)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 72 : 24,
                vertical: isLandscape ? 14 : 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // The status line sits above the bar so the bar itself is
                  // the last thing before the safe-area edge in both
                  // orientations.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          boot.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0x99101C13), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppGap.md),
                      Text(
                        '${(_displayed * 100).round()}%',
                        style: AppText.title.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x99101C13), blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppGap.sm + 2),
                  _ProgressTrough(value: _displayed, height: 10),
                  SizedBox(height: isLandscape ? 4 : 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat horizontal track that fills left to right. The splash owns a
/// timed 0 → 80 % climb; the last 20 % is reserved for the actual hand-off.
class _ProgressTrough extends StatelessWidget {
  const _ProgressTrough({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(height),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fill = constraints.maxWidth * t;
                if (fill <= 0) return const SizedBox.expand();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: fill,
                    height: constraints.maxHeight,
                    child: const ColoredBox(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
