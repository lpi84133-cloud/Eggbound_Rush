import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'art.dart';
import 'surfaces.dart';

/// Label, optional hint, and the control beneath it. Every field in the app
/// is wrapped in this, which is what makes the hen form and the feed form
/// look like the same form.
class FieldShell extends StatelessWidget {
  const FieldShell({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.ink)),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!, style: AppText.caption),
        ],
        const SizedBox(height: AppGap.sm),
        child,
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.numeric = false,
    this.textCapitalization = TextCapitalization.none,
    this.prefix,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final int maxLines;
  final bool numeric;
  final TextCapitalization textCapitalization;
  final Widget? prefix;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1.0]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.brSmall,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction ??
          (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      onSubmitted: onSubmitted,
      style: AppText.bodyStrong.copyWith(color: AppColors.ink),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle:
            AppText.label.copyWith(color: AppColors.accent, fontSize: 12),
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: AppColors.inkFaint),
        helperText: helper,
        helperStyle: AppText.caption,
        prefixIcon: prefix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.accent, 2.0),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 2.0),
      ),
    );
  }
}

/// Tappable date row. Shared by the hen form, the treatment sheet and the
/// feed sheet so a date always looks and behaves the same way.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.hint,
    this.emptyLabel = 'Not set',
    this.onClear,
    this.icon = Icons.calendar_today_rounded,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final String? hint;
  final String emptyLabel;
  final VoidCallback? onClear;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      label: label,
      hint: hint,
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: onPick,
        child: Row(
          children: [
            IconChip(icon: icon, size: 34),
            const SizedBox(width: AppGap.md - 2),
            Expanded(
              child: Text(
                value == null ? emptyLabel : formatDate(value!),
                style: value == null
                    ? AppText.body
                    : AppText.bodyStrong,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.inkFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Large plus/minus counter. Sized for a thumb because it gets used standing
/// in a chicken run, often one-handed.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 60,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMedium,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          _StepKey(
            icon: Icons.remove_rounded,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: AppText.hero.copyWith(fontSize: 38),
              ),
            ),
          ),
          _StepKey(
            icon: Icons.add_rounded,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepKey extends StatelessWidget {
  const _StepKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.accentSoft : AppColors.surfaceAlt,
      borderRadius: AppRadius.brSmall,
      child: InkWell(
        borderRadius: AppRadius.brSmall,
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: 54,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppColors.accentDeep : AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

/// Every bottom sheet in the app is built from this: grabber, title block,
/// scrollable body that respects the keyboard, and a pinned action.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Widget> Function(BuildContext context) body,
  Widget? action,
  String? art,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66201808),
    builder: (context) => AppSheet(
      title: title,
      subtitle: subtitle,
      action: action,
      art: art,
      children: body(context),
    ),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
    this.art,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;
  final String? art;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Leave a strip of the screen visible so the sheet always reads as a
    // layer over the page rather than as a new screen.
    final maxHeight = media.size.height - media.padding.top - 24;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: AppRadius.large),
            boxShadow: AppShadow.floating,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: AppText.display),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppGap.xs),
                              Text(subtitle!, style: AppText.body),
                            ],
                          ],
                        ),
                      ),
                      if (art != null) ...[
                        const SizedBox(width: AppGap.md),
                        Sprite(art!, size: 56),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, AppGap.lg, 20, 4),
                      children: children,
                    ),
                  ),
                ),
                if (action != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    decoration: const BoxDecoration(
                      color: AppColors.canvas,
                      border: Border(
                        top: BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: action,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Short form for dense lists where the year is obvious from context.
String formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';
