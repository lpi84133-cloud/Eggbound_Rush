import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The app ships real illustrations of the things it tracks, so a screen
/// about eggs shows eggs. Referencing them through one place keeps the same
/// hen, egg and coin turning up in the same roles everywhere.
abstract final class Art {
  static const hen = 'assets/app/images/chicken_idle.png';
  static const henWalking = 'assets/app/images/chicken_walk.png';
  static const henPecking = 'assets/app/images/chicken_peck.png';
  static const henNesting = 'assets/app/images/chicken_nesting.png';
  static const egg = 'assets/app/images/egg_white.png';
  static const eggGolden = 'assets/app/images/egg_golden.png';
  static const eggPatterned = 'assets/app/images/egg_patterned.png';
  static const nest = 'assets/app/images/nest.png';
  static const basket = 'assets/app/images/basket.png';
  static const trough = 'assets/app/images/feed_trough.png';
  static const water = 'assets/app/images/water_trough.png';
  static const hay = 'assets/app/images/hay_bale.png';
  static const coin = 'assets/app/images/point_badge.png';
  static const coins = 'assets/app/images/point_badge_stack.png';
  static const grass = 'assets/app/images/grass_tuft.png';
  static const flower = 'assets/app/images/flower.png';
  static const sun = 'assets/app/images/sun.png';
  static const fence = 'assets/app/images/fence.png';
  static const signpost = 'assets/app/images/signpost.png';
}

/// A sprite at a fixed logical size, decoded at exactly the resolution it is
/// drawn at. Every illustration in the app goes through this so none of them
/// decodes a full-size bitmap for a 24pt slot.
class Sprite extends StatelessWidget {
  const Sprite(this.asset, {super.key, required this.size, this.opacity = 1});

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return opacity == 1 ? image : Opacity(opacity: opacity, child: image);
  }
}

/// The green band that tops every screen, carrying the title and a hen
/// looking in from the right. It is the strongest single element of the
/// identity, and it appears on all screens so they read as one product.
class GreenAppBar extends StatelessWidget {
  const GreenAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.mascot = Art.hen,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final String? mascot;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.bar,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: AppShadow.floating,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (mascot != null)
            Positioned(
              right: 6,
              bottom: bottom == null ? -6 : 4,
              child: IgnorePointer(
                child: Sprite(mascot!, size: 74, opacity: 0.95),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              onBack != null ? 4 : 18,
              topInset + 6,
              mascot == null ? 12 : 84,
              bottom == null ? 16 : 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      _BarButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack!,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title.copyWith(color: Colors.white),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                if (bottom != null) ...[
                  const SizedBox(height: AppGap.md),
                  bottom!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Circular action on the green bar, filled so it reads against the gradient.
class BarAction extends StatelessWidget {
  const BarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// A quantity drawn as that many eggs. Counting objects is immediate in a way
/// a numeral is not, and it makes a screen about egg production actually look
/// like one.
class EggGrid extends StatelessWidget {
  const EggGrid({
    super.key,
    required this.count,
    this.eggSize = 30,
    this.perRow = 7,
    this.max = 28,
    this.asset = Art.egg,
  });

  final int count;
  final double eggSize;
  final int perRow;
  final int max;
  final String asset;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Row(
        children: [
          Sprite(asset, size: eggSize, opacity: 0.28),
          const SizedBox(width: AppGap.sm),
          Expanded(
            child: Text('Nothing collected yet today', style: AppText.caption),
          ),
        ],
      );
    }

    final shown = math.min(count, max);
    final overflow = count - shown;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < shown; i++) Sprite(asset, size: eggSize),
        if (overflow > 0)
          Container(
            height: eggSize,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(eggSize / 2),
            ),
            child: Text(
              '+$overflow',
              style: AppText.label.copyWith(
                color: AppColors.goldDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// A 240° arc coloured along the low-to-high ramp, with the figure in the
/// middle. Used for lay rate, where the position on the ramp says as much as
/// the number does.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.value,
    required this.label,
    required this.caption,
    this.size = 150,
  });

  final double value;
  final String label;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: CustomPaint(
        painter: _ArcPainter(value.clamp(0.0, 1.0)),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(caption, style: AppText.overline),
              const SizedBox(height: 2),
              Text(label, style: AppText.metric.copyWith(fontSize: 30)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.value);

  final double value;

  static const _start = math.pi * 0.85;
  static const _sweep = math.pi * 1.30;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.width - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceAlt;
    canvas.drawArc(rect, _start, _sweep, false, track);

    final filled = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [
          AppColors.rampPeak,
          AppColors.rampHigh,
          AppColors.rampMid,
          AppColors.rampLow,
        ],
        transform: GradientRotation(_start),
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * value, false, filled);

    // A knob on the leading edge makes the exact position readable.
    final angle = _start + _sweep * value;
    final centre = rect.center;
    final radius = rect.width / 2;
    final knob = Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(knob, stroke * 0.62, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      stroke * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.forest,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

/// Icon, label, coloured bar, value and share — the row the reference layout
/// uses for every breakdown. One component for feed spend, per-hen output
/// and workload keeps those three readable as the same kind of thing.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.tone,
    this.leading,
    this.share,
    this.onTap,
  });

  final String label;
  final String value;
  final double fraction;
  final Color tone;
  final Widget? leading;
  final String? share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppGap.sm + 2),
          ],
          SizedBox(
            width: 74,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: AppColors.ink),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 9,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: AppColors.surfaceAlt,
                      child: SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppGap.sm + 2),
          SizedBox(
            width: 54,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (share != null)
            SizedBox(
              width: 40,
              child: Text(
                share!,
                textAlign: TextAlign.right,
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Small coloured pill: "High", "Laying", "3 days late". Tone is the whole
/// message, so the same three tones are used everywhere.
class ToneBadge extends StatelessWidget {
  const ToneBadge({
    super.key,
    required this.label,
    required this.tone,
    this.dot = false,
  });

  final String label;
  final Color tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(dot ? 8 : 10, 4, 10, 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.caption.copyWith(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Area chart with the ramp gradient under it. Reads as a landscape profile,
/// which is exactly how a run of good and bad laying days feels.
class RidgeChart extends StatelessWidget {
  const RidgeChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 130,
  });

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _RidgePainter(values),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in labels)
                Text(label, style: AppText.caption.copyWith(fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RidgePainter extends CustomPainter {
  const _RidgePainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final peak = values.fold<int>(1, (m, v) => v > m ? v : m);
    final step = size.width / (values.length - 1);

    Offset pointAt(int i) => Offset(
          step * i,
          size.height - (values[i] / peak) * (size.height - 10) - 4,
        );

    final line = Path()..moveTo(0, pointAt(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final current = pointAt(i);
      final next = pointAt(i + 1);
      // Horizontal control points give a smooth ridge without overshooting
      // above the peak, which a plain cubic through the points would do.
      final midX = (current.dx + next.dx) / 2;
      line.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.rampLow.withValues(alpha: 0.55),
            AppColors.rampLow.withValues(alpha: 0.06),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent,
    );

    // Mark the best day so the chart states a fact, not just a shape.
    final bestIndex = values.indexOf(peak);
    final best = pointAt(bestIndex);
    canvas.drawCircle(best, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      best,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(_RidgePainter old) => true;
}

/// Decorative strip that closes a scrolling screen, so the page ends on the
/// world of the app rather than on empty cream.
class MeadowFooter extends StatelessWidget {
  const MeadowFooter({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppGap.xl),
      child: Column(
        children: [
          if (message != null) ...[
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: AppGap.md),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Sprite(Art.grass, size: 34, opacity: 0.55),
              SizedBox(width: 6),
              Sprite(Art.henPecking, size: 52, opacity: 0.75),
              SizedBox(width: 10),
              Sprite(Art.nest, size: 40, opacity: 0.6),
              SizedBox(width: 6),
              Sprite(Art.flower, size: 26, opacity: 0.5),
            ],
          ),
        ],
      ),
    );
  }
}
