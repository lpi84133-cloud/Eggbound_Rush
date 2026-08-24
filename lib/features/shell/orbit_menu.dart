import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

class OrbitDestination {
  const OrbitDestination({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// Navigation that unfolds as a curved fan from a single anchor instead of a
/// bottom tab bar, so the pasture board is never covered by permanent chrome.
class OrbitMenu extends StatefulWidget {
  const OrbitMenu({
    super.key,
    required this.destinations,
    required this.onToggle,
  });

  final List<OrbitDestination> destinations;
  final ValueChanged<bool> onToggle;

  @override
  State<OrbitMenu> createState() => OrbitMenuState();
}

class OrbitMenuState extends State<OrbitMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );

  static const _anchorSize = 62.0;
  static const _itemHeight = 50.0;
  static const _itemGap = 11.0;

  double _itemHeightFor(double available) {
    final count = widget.destinations.length;
    final needed = _anchorSize + 16 + count * (_itemHeight + _itemGap);
    if (needed <= available) return _itemHeight;
    // On a landscape phone the full-size fan would run off the top of the
    // screen. Shrink the rows to fit rather than clipping the last option.
    final perItem = (available - _anchorSize - 16) / count - _itemGap;
    return perItem.clamp(38.0, _itemHeight);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final opening = _controller.value < 0.5;
    opening ? _controller.forward() : _controller.reverse();
    widget.onToggle(opening);
  }

  void close() {
    _controller.reverse();
    widget.onToggle(false);
  }

  void _select(OrbitDestination destination) {
    close();
    destination.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.destinations.length;
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.padding.top - media.padding.bottom - 40;
    final itemHeight = _itemHeightFor(available);
    final stackHeight = _anchorSize + 16 + count * (itemHeight + _itemGap);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 236,
          height: stackHeight,
          child: Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++)
                _fanItem(i, count, widget.destinations[i], itemHeight),
              Positioned(
                right: 0,
                bottom: 0,
                child: _AnchorButton(
                  size: _anchorSize,
                  progress: _controller.value,
                  onTap: _toggle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fanItem(
    int index,
    int count,
    OrbitDestination destination,
    double itemHeight,
  ) {
    // Items closest to the anchor lead the animation, giving the fan a sense
    // of unfolding rather than everything appearing at once.
    final stagger = (index / (count * 1.6)).clamp(0.0, 0.6);
    final local = ((_controller.value - stagger) / (1 - stagger))
        .clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);

    // A gentle sideways bow so the column reads as an arc, not a list.
    final bow = math.sin(math.pi * (index + 1) / (count + 1)) * 20;
    final travel = _anchorSize + 16 + index * (itemHeight + _itemGap);

    return Positioned(
      right: 6 + bow * eased,
      bottom: travel * eased,
      child: IgnorePointer(
        ignoring: local < 0.6,
        child: Opacity(
          opacity: eased,
          child: Transform.scale(
            scale: 0.82 + 0.18 * eased,
            alignment: Alignment.bottomRight,
            child: _FanButton(
              destination: destination,
              height: itemHeight,
              onTap: () => _select(destination),
            ),
          ),
        ),
      ),
    );
  }
}

class _FanButton extends StatelessWidget {
  const _FanButton({
    required this.destination,
    required this.height,
    required this.onTap,
  });

  final OrbitDestination destination;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadow.floating,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(destination.icon,
                        color: AppColors.accentDeep, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    destination.label,
                    style: AppText.button.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchorButton extends StatelessWidget {
  const _AnchorButton({
    required this.size,
    required this.progress,
    required this.onTap,
  });

  final double size;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        shape: BoxShape.circle,
        boxShadow: AppShadow.accent,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              // A quarter turn as the fan opens: the same control, visibly in
              // a different state, rather than two different-looking buttons.
              child: Transform.rotate(
                angle: progress * math.pi * 0.5,
                child: Icon(
                  progress > 0.5 ? Icons.close_rounded : Icons.apps_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared page transition for everything opened from the orbit menu.
Route<T> orbitRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.06, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
