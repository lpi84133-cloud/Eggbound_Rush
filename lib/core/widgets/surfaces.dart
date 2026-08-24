import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'art.dart';

/// The base surface. Everything that holds content sits on one of these, so
/// a card in the feed section is indistinguishable from a card in the flock
/// section — which is what stops the app looking like unrelated screens
/// stitched together.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppGap.md + 2),
    this.color = AppColors.surface,
    this.borderRadius = AppRadius.brMedium,
    this.onTap,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: AppColors.line),
        boxShadow: shadow ? AppShadow.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          border: border ?? Border.all(color: AppColors.line),
          boxShadow: shadow ? AppShadow.card : null,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The one figure a screen exists to communicate, on the accent gradient,
/// with an illustration of whatever is being counted. Exactly one per screen.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.trailing,
    this.gradient = AppGradients.hero,
    this.onTap,
    this.art,
    this.unit,
  });

  final String value;
  final String label;
  final String? caption;
  final Widget? trailing;
  final Gradient gradient;
  final VoidCallback? onTap;
  final String? art;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppText.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: AppGap.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: AppText.hero.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        unit!,
                        style: AppText.section.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppGap.xs + 2),
                  Text(
                    caption!,
                    style: AppText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppGap.sm),
            trailing!,
          ] else if (art != null) ...[
            const SizedBox(width: AppGap.sm),
            Sprite(art!, size: 84),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadius.brMedium,
        boxShadow: AppShadow.accent,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: AppRadius.brMedium,
              child: InkWell(
                borderRadius: AppRadius.brMedium,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

/// A metric backed by an illustration rather than a Material icon. These are
/// what fill the summary grids, and the artwork is what stops a grid of
/// numbers reading as a spreadsheet.
class ArtTile extends StatelessWidget {
  const ArtTile({
    super.key,
    required this.art,
    required this.value,
    required this.label,
    this.tone = AppColors.ink,
    this.badge,
    this.onTap,
  });

  final String art;
  final String value;
  final String label;
  final Color tone;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Sprite(art, size: 30),
              const Spacer(),
              if (badge != null) ToneBadge(label: badge!, tone: tone),
            ],
          ),
          const SizedBox(height: AppGap.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.metric.copyWith(color: tone)),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Rounded-square icon holder. Every icon that sits beside text in this app
/// uses one, at one of two sizes, so lists line up down the page.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.tone = AppColors.accent,
    this.background,
    this.size = 40,
  });

  final IconData icon;
  final Color tone;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.48, color: tone),
    );
  }
}

/// Screen header. Every screen gets the same green band with a hen looking
/// in from the right, which is the strongest single cue that these screens
/// belong to one product.
class RibbonHeader extends StatelessWidget {
  const RibbonHeader({
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
    return GreenAppBar(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      trailing: trailing,
      mascot: mascot,
      bottom: bottom,
    );
  }
}

/// Circular header action. Sits on the green band, so it is a translucent
/// white fill rather than a tinted one.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) =>
      BarAction(icon: icon, onPressed: onPressed, tooltip: tooltip);
}

enum PillTone { primary, accent, quiet, danger, ghost }

/// The app's only button. Tone selects meaning, never a screen's identity.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = PillTone.primary,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PillTone tone;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (background, foreground, border, glow) = switch (tone) {
      PillTone.primary => (
          AppColors.forest,
          AppColors.onAccent,
          null,
          AppShadow.accent,
        ),
      PillTone.accent => (AppColors.gold, AppColors.ink, null, AppShadow.gold),
      PillTone.quiet => (
          AppColors.surface,
          AppColors.ink,
          Border.all(color: AppColors.lineStrong),
          AppShadow.card,
        ),
      PillTone.danger => (AppColors.dangerSoft, AppColors.danger, null, null),
      PillTone.ghost => (Colors.transparent, AppColors.forest, null, null),
    };

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brSmall,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.brSmall,
            border: border,
            boxShadow: enabled ? glow : null,
          ),
          child: InkWell(
            borderRadius: AppRadius.brSmall,
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20,
                vertical: compact ? 10 : 14,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: compact ? 17 : 19, color: foreground),
                    const SizedBox(width: AppGap.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.button.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Group heading. The small caps overline reads as structure, leaving the
/// bold weights free to mark actual content.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppGap.lg + 4, 2, AppGap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // A short gold rule anchors the heading to the left edge and adds
          // the one bit of warmth a plain caps label was missing.
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 9, bottom: 1),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.toUpperCase(),
                  style: AppText.overline.copyWith(color: AppColors.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppText.caption),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Explains what an empty area is for and how to fill it, so no screen ever
/// renders as a blank shell.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.art,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // An empty state is where the app has the least to say, so it is
          // exactly where the illustration matters most.
          if (art != null)
            Sprite(art!, size: 84)
          else
            IconChip(icon: icon, size: 56),
          const SizedBox(height: AppGap.md),
          Text(title, style: AppText.section, textAlign: TextAlign.center),
          const SizedBox(height: AppGap.xs + 2),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppGap.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A quiet aside. Tone matches the semantic palette so an informational note
/// and a warning are told apart by colour alone.
class InfoNote extends StatelessWidget {
  const InfoNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.tone = InfoTone.neutral,
  });

  final String text;
  final IconData icon;
  final InfoTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      InfoTone.neutral => (AppColors.surfaceAlt, AppColors.inkMuted),
      InfoTone.positive => (AppColors.accentSoft, AppColors.accentDeep),
      InfoTone.warning => (AppColors.warnSoft, AppColors.warn),
      InfoTone.danger => (AppColors.dangerSoft, AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppGap.md - 2),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: tone == InfoTone.neutral
                    ? AppColors.inkMuted
                    : foreground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum InfoTone { neutral, positive, warning, danger }

/// Inline switcher for a range or a mode. Sliding indicator, no colour fill,
/// so it never competes with the primary action on the screen.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected).clamp(0, values.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 8) / values.length;
        return Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: slot * index,
                width: slot,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: AppShadow.card,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(value),
                        child: Center(
                          child: Text(
                            labelOf(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label.copyWith(
                              color: value == selected
                                  ? AppColors.ink
                                  : AppColors.inkFaint,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Selectable chip used for every "pick one of these" control: egg colour,
/// laying status, treatment type. One component means those three controls
/// cannot drift apart visually.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest : AppColors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        splashColor: AppColors.accentSoft.withValues(alpha: 0.3),
        highlightColor: AppColors.accentSoft.withValues(alpha: 0.2),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.line,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(leading == null ? 14 : 8, 9, 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppGap.sm),
                ],
                Text(
                  label,
                  style: AppText.label.copyWith(
                    color: selected ? Colors.white : AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows inside a card: an icon chip, a title with optional detail, and a
/// trailing value. Used by every list in the app.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });

  final String title;
  final String? detail;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppGap.md),
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
                  style: AppText.bodyStrong,
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppGap.md),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: AppGap.xs),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.inkFaint),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Stacks rows inside one card with hairlines between them, so a list reads
/// as a single object rather than a pile of separate cards.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Divider(height: 1, thickness: 1, color: AppColors.line),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One labelled figure. The building block of every summary block.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone = AppColors.ink,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: tone),
            const SizedBox(height: AppGap.sm),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.metric.copyWith(color: tone)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Slim progress track used for lay rates and comparisons.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.tone = AppColors.accent,
    this.height = 8,
  });

  final double value;
  final Color tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: AppColors.surfaceAlt,
          valueColor: AlwaysStoppedAnimation(tone),
        ),
      ),
    );
  }
}
