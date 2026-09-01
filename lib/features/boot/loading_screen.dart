import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../gray/gray_router.dart';
import 'boot_controller.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// The value painted on screen. It chases the real progress instead of
  /// jumping, but it is never allowed to run ahead of it.
  double _displayed = 0;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bootControllerProvider.notifier).start(context);
    });
  }

  void _onTick(Duration elapsed) {
    final delta = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final boot = ref.read(bootControllerProvider);
    final kind = ref.read(grayRouterProvider).kind;

    // The bar is the whole launch, so what it counts depends on where the
    // launch ends. Heading for the WebView there is no native work left to
    // wait for; heading for the game it is the boot tasks. Until the server
    // has answered, the bar holds short of the end so it never sits full
    // while something is still pending.
    final target = switch (kind) {
      GrayKind.pending => math.min(boot.progress, 0.92),
      GrayKind.webview => 1.0,
      GrayKind.stub => boot.progress,
    };

    if (_displayed < target) {
      // Ease toward the target, but keep a floor so the bar always visibly
      // advances, and a ceiling so a big jump still reads as motion.
      final remaining = target - _displayed;
      final step = math.max(remaining * delta * 6.0, delta * 0.18);
      setState(() => _displayed = math.min(target, _displayed + step));
    }

    final launchable = switch (kind) {
      GrayKind.pending => false,
      GrayKind.webview => true,
      GrayKind.stub => boot.isReady,
    };
    if (launchable && _displayed >= 0.9995) _finish();
  }

  void _finish() {
    if (_handedOff) return;
    _handedOff = true;
    _ticker.stop();
    setState(() => _displayed = 1);
    // Handing off inside the tick would swap the screen in the same frame the
    // bar is completed, so the full bar would never be painted. One frame
    // later it has been drawn and the app takes over immediately after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(grayRouterProvider);
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

/// A flat horizontal track that fills left to right. It reports real boot
/// progress, so the percentage beside it is the share of startup work that
/// has genuinely finished rather than a timed animation.
class _ProgressTrough extends StatelessWidget {
  const _ProgressTrough({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final filled = (width * value).clamp(0.0, width);

        return SizedBox(
          width: width,
          height: height,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: math.max(0, filled - 4),
                    height: height - 4,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
